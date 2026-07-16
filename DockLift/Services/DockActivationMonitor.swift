//
//  DockActivationMonitor.swift
//  DockLift
//
//  Observes Dock clicks + app activation and lifts windows onto the Dock screen.
//
//  Important multi-display case: if the target app is *already* frontmost (its
//  window sits on another display), `didActivateApplication` does **not** fire
//  when the Dock icon is clicked. We therefore also handle a delayed re-click
//  of the current frontmost app after a Dock-region mouse down.
//

import AppKit
import Combine
import CoreGraphics
import Foundation
import os.log

private let log = Logger(subsystem: Bundle.main.bundleIdentifier ?? "DockLift", category: "DockMonitor")

/// Configuration snapshot used for a single activation handling pass.
struct LiftPolicy: Sendable {
    var isEnabled: Bool
    var onlyWhenDockClick: Bool
    var includeMinimizedWindows: Bool
    var preferMoveToCurrentSpace: Bool
    var moveToDockScreen: Bool
    var useMinimizeFallback: Bool
    var ignoredBundleIdentifiers: Set<String>
}

/// Listens for `NSWorkspace.didActivateApplicationNotification` and Dock clicks.
@MainActor
final class DockActivationMonitor: ObservableObject {
    @Published private(set) var lastLiftedAppName: String?
    @Published private(set) var lastEventDescription: String = String(localized: "Waiting for Dock activity…")
    @Published private(set) var isRunning = false

    private let windowManager: WindowManager
    private var activationObserver: NSObjectProtocol?
    private var mouseDownMonitor: Any?
    private var mouseUpMonitor: Any?

    /// Last time a primary click was observed inside the Dock strip.
    private var lastDockClickAt: Date?
    /// Display id of the screen whose Dock received the last click.
    private var lastDockClickDisplayID: CGDirectDisplayID?
    /// Debounce repeated handling for the same pid.
    private var lastHandled: (pid: pid_t, at: Date)?
    /// Serial generation so delayed dock re-click tasks can be cancelled logically.
    private var dockClickGeneration: UInt64 = 0

    /// Supplies the current policy (read from settings by the view model).
    var policyProvider: (() -> LiftPolicy)?

    init(windowManager: WindowManager? = nil) {
        self.windowManager = windowManager ?? .shared
    }

    // MARK: - Lifecycle

    func start() {
        guard !isRunning else { return }
        isRunning = true

        activationObserver = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didActivateApplicationNotification,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            MainActor.assumeIsolated {
                self?.handleActivation(notification)
            }
        }

        // Global monitors only — local monitors break Settings hit-testing.
        mouseDownMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown]) { [weak self] _ in
            let location = NSEvent.mouseLocation
            Task { @MainActor [weak self] in
                self?.recordPotentialDockClick(at: location)
            }
        }
        mouseUpMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseUp]) { [weak self] _ in
            let location = NSEvent.mouseLocation
            Task { @MainActor [weak self] in
                self?.recordPotentialDockMouseUp(at: location)
            }
        }

        lastEventDescription = String(localized: "Monitoring Dock activations")
        log.info("DockActivationMonitor started")
    }

    func stop() {
        if let activationObserver {
            NSWorkspace.shared.notificationCenter.removeObserver(activationObserver)
            self.activationObserver = nil
        }
        if let mouseDownMonitor {
            NSEvent.removeMonitor(mouseDownMonitor)
            self.mouseDownMonitor = nil
        }
        if let mouseUpMonitor {
            NSEvent.removeMonitor(mouseUpMonitor)
            self.mouseUpMonitor = nil
        }
        isRunning = false
        lastEventDescription = String(localized: "Monitoring paused")
        log.info("DockActivationMonitor stopped")
    }

    // MARK: - Click tracking

    private func recordPotentialDockClick(at location: CGPoint) {
        guard let dockScreen = DockGeometry.screenHostingDock(at: location) else { return }

        lastDockClickAt = Date()
        lastDockClickDisplayID = ScreenCoordinates.displayID(of: dockScreen)
        dockClickGeneration &+= 1
        let generation = dockClickGeneration

        log.debug(
            "Dock click on display \(self.lastDockClickDisplayID ?? 0, privacy: .public) at \(location.x, privacy: .public),\(location.y, privacy: .public)"
        )

        // Already-frontmost apps do not emit didActivateApplication when their
        // Dock icon is clicked. Schedule a follow-up after the click settles.
        Task { @MainActor [weak self] in
            try? await Task.sleep(for: .milliseconds(220))
            guard let self, self.isRunning, self.dockClickGeneration == generation else { return }
            self.handleDockReclickOfFrontmostApp()
        }
    }

    private func recordPotentialDockMouseUp(at location: CGPoint) {
        // If the press started on the Dock, keep the dock-click timestamp fresh
        // through mouse-up (activation often lands between down and up).
        if let lastDockClickAt, Date().timeIntervalSince(lastDockClickAt) < 0.9 {
            if DockGeometry.screenHostingDock(at: location) != nil
                || DockGeometry.contains(location)
            {
                self.lastDockClickAt = Date()
                if let screen = DockGeometry.screenHostingDock(at: location) {
                    lastDockClickDisplayID = ScreenCoordinates.displayID(of: screen)
                }
            }
        }
    }

    /// Heuristic: activation soon after a Dock-region click, or pointer still over Dock.
    private func isLikelyDockTriggered() -> Bool {
        if let lastDockClickAt, Date().timeIntervalSince(lastDockClickAt) < 0.9 {
            return true
        }
        return DockGeometry.screenHostingDock(at: NSEvent.mouseLocation) != nil
    }

    /// Display that should receive the window after a Dock activation.
    private func targetDisplayID() -> CGDirectDisplayID? {
        if let lastDockClickAt,
           Date().timeIntervalSince(lastDockClickAt) < 0.9,
           let lastDockClickDisplayID
        {
            return lastDockClickDisplayID
        }
        if let dockScreen = DockGeometry.screenHostingDock(at: NSEvent.mouseLocation) {
            return ScreenCoordinates.displayID(of: dockScreen)
        }
        // Prefer the screen under the pointer (where the user is working).
        if let underPointer = ScreenCoordinates.screen(containingAppKitPoint: NSEvent.mouseLocation) {
            return ScreenCoordinates.displayID(of: underPointer)
        }
        if let screen = DockGeometry.activeDockScreen() {
            return ScreenCoordinates.displayID(of: screen)
        }
        return nil
    }

    // MARK: - Already-active app Dock re-click

    /// Handles Dock clicks when the app is already frontmost (no activation notification).
    private func handleDockReclickOfFrontmostApp() {
        let policy = currentPolicy()
        guard policy.isEnabled else { return }
        guard windowManager.isAccessibilityTrusted else { return }
        guard policy.moveToDockScreen || policy.preferMoveToCurrentSpace else { return }

        // Still consider this a recent Dock interaction.
        guard let lastDockClickAt, Date().timeIntervalSince(lastDockClickAt) < 0.9 else { return }

        guard let app = NSWorkspace.shared.frontmostApplication else { return }

        // DockLift itself: Settings may sit on another display while we are frontmost.
        // Do not use AX lift (we ignore our own bundle); move NSWindows directly.
        if app.processIdentifier == ProcessInfo.processInfo.processIdentifier {
            OpenSettingsAction.bringOwnWindowsToDockScreen()
            lastEventDescription = String(localized: "Brought Settings to Dock screen")
            return
        }

        if app.isTerminated || app.activationPolicy != .regular { return }

        if let bundleID = app.bundleIdentifier, policy.ignoredBundleIdentifiers.contains(bundleID) {
            return
        }

        // If activation handling already lifted this app, skip.
        if let lastHandled,
           lastHandled.pid == app.processIdentifier,
           Date().timeIntervalSince(lastHandled.at) < 0.5
        {
            return
        }

        // Only pull windows that are actually off the Dock's display (or Space).
        let displayID = targetDisplayID()
        let needsWork: Bool
        do {
            needsWork = try windowManager.needsLift(
                for: app,
                targetDisplayID: displayID,
                includeMinimized: policy.includeMinimizedWindows
            )
        } catch {
            needsWork = true
        }
        guard needsWork else {
            log.debug("Frontmost app already on Dock screen — skip re-click lift")
            return
        }

        lastHandled = (app.processIdentifier, Date())
        log.info("Dock re-click of already-frontmost app \(app.localizedName ?? "?", privacy: .public)")
        lift(app: app, policy: policy)
    }

    // MARK: - Activation

    private func currentPolicy() -> LiftPolicy {
        policyProvider?() ?? LiftPolicy(
            isEnabled: true,
            onlyWhenDockClick: true,
            includeMinimizedWindows: true,
            preferMoveToCurrentSpace: true,
            moveToDockScreen: true,
            useMinimizeFallback: true,
            ignoredBundleIdentifiers: []
        )
    }

    private func handleActivation(_ notification: Notification) {
        let policy = currentPolicy()

        guard policy.isEnabled else { return }
        guard windowManager.isAccessibilityTrusted else {
            lastEventDescription = String(localized: "Skipped: Accessibility not granted")
            return
        }

        guard
            let app = notification.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication
        else {
            return
        }

        // Own app activation via Dock — move Settings to the Dock's screen.
        if app.processIdentifier == ProcessInfo.processInfo.processIdentifier {
            if isLikelyDockTriggered() {
                OpenSettingsAction.bringOwnWindowsToDockScreen()
                lastEventDescription = String(localized: "Brought Settings to Dock screen")
            }
            return
        }

        if app.isTerminated { return }

        if let bundleID = app.bundleIdentifier, policy.ignoredBundleIdentifiers.contains(bundleID) {
            let name = app.localizedName ?? bundleID
            lastEventDescription = String(format: String(localized: "Ignored %@"), name)
            return
        }

        if app.activationPolicy != .regular { return }

        if policy.onlyWhenDockClick && !isLikelyDockTriggered() {
            let name = app.localizedName ?? String(localized: "App")
            lastEventDescription = String(
                format: String(localized: "Activation of %@ (not Dock)"),
                name
            )
            return
        }

        if let lastHandled,
           lastHandled.pid == app.processIdentifier,
           Date().timeIntervalSince(lastHandled.at) < 0.35
        {
            return
        }
        lastHandled = (app.processIdentifier, Date())

        lift(app: app, policy: policy)
    }

    private func lift(app: NSRunningApplication, policy: LiftPolicy) {
        let name = app.localizedName ?? app.bundleIdentifier ?? String(localized: "App")
        let displayID = targetDisplayID()

        let target = LiftTarget(
            screenDisplayID: displayID,
            preferMoveToCurrentSpace: policy.preferMoveToCurrentSpace,
            moveToDockScreen: policy.moveToDockScreen,
            useMinimizeFallback: policy.useMinimizeFallback,
            includeMinimized: policy.includeMinimizedWindows
        )

        do {
            let result = try windowManager.liftMostRecentWindow(of: app, target: target)
            lastLiftedAppName = name

            var notes: [String] = []
            if result.movedToScreen {
                notes.append(String(localized: "moved to Dock screen"))
            }
            if result.movedAcrossSpace {
                notes.append(String(localized: "from other Space"))
            }
            let suffix: String
            if notes.isEmpty {
                suffix = ""
            } else {
                suffix = String(
                    format: String(localized: " (%@)"),
                    notes.joined(separator: ", ")
                )
            }
            let title = result.window.title.isEmpty ? name : result.window.title
            lastEventDescription = String(
                format: String(localized: "Lifted “%@”%@"),
                title,
                suffix
            )
            log.info("Lifted window for \(name, privacy: .public)\(suffix, privacy: .public)")
        } catch WindowManagerError.noWindows {
            lastEventDescription = String(
                format: String(localized: "%@ has no windows to lift"),
                name
            )
        } catch {
            lastEventDescription = String(
                format: String(localized: "Failed for %@: %@"),
                name,
                error.localizedDescription
            )
            log.error("Lift failed: \(error.localizedDescription, privacy: .public)")
        }
    }
}
