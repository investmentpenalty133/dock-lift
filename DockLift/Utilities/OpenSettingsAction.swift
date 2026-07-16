//
//  OpenSettingsAction.swift
//  DockLift
//
//  Reliable Settings presentation for MenuBarExtra (LSUIElement) apps.
//  Gates Settings behind Accessibility authorization via PermissionFlow.
//

import AppKit
import ApplicationServices
import SwiftUI

extension Notification.Name {
    /// Open Settings only when Accessibility is already granted.
    static let dockLiftOpenSettings = Notification.Name("dockLiftOpenSettings")
    /// Present the permission gate window (no Settings until authorized).
    static let dockLiftOpenPermissionGate = Notification.Name("dockLiftOpenPermissionGate")
}

enum OpenSettingsAction {
    static let bootstrapWindowID = "docklift.settings.bootstrap"
    static let permissionGateWindowID = "docklift.permission.gate"

    /// Public entry: Settings if trusted, otherwise permission gate.
    static func request() {
        DispatchQueue.main.async {
            if AXIsProcessTrusted() {
                requestSettings(force: true)
            } else {
                requestPermissionGate()
            }
        }
    }

    /// Open Settings scene (caller must ensure Accessibility is granted, or pass force after check).
    static func requestSettings(force: Bool = false) {
        DispatchQueue.main.async {
            if force || AXIsProcessTrusted() {
                NotificationCenter.default.post(name: .dockLiftOpenSettings, object: nil)
            } else {
                requestPermissionGate()
            }
        }
    }

    static func requestPermissionGate() {
        DispatchQueue.main.async {
            NotificationCenter.default.post(name: .dockLiftOpenPermissionGate, object: nil)
        }
    }

    /// Best-effort locate the SwiftUI Settings window.
    static func findSettingsWindow() -> NSWindow? {
        let candidates = NSApp.windows.filter { window in
            guard window.frame.width > 50, window.frame.height > 50 else { return false }
            if window.identifier?.rawValue.contains("SwiftUI.Settings") == true {
                return true
            }
            let title = window.title.lowercased()
            if title.contains("settings") || title.contains("preferences") || title.contains("docklift") {
                return window.styleMask.contains(.titled)
            }
            let typeName = String(describing: type(of: window))
            if typeName.contains("Settings") { return true }
            if let vc = window.contentViewController {
                let vcName = String(describing: type(of: vc))
                if vcName.contains("Settings") { return true }
            }
            return false
        }
        return candidates.first
    }

    static func focusSettingsWindow() {
        guard let window = findSettingsWindow() else { return }
        window.makeKeyAndOrderFront(nil)
        window.orderFrontRegardless()
    }
}

/// Lives inside the hidden bootstrap `Window` scene.
struct SettingsBootstrapView: View {
    @Environment(\.openSettings) private var openSettings
    @Environment(\.openWindow) private var openWindow
    @EnvironmentObject private var viewModel: AppViewModel

    @State private var didAutoOpenThisSession = false

    var body: some View {
        Color.clear
            .frame(width: 1, height: 1)
            .accessibilityHidden(true)
            .background(BootstrapWindowHider())
            .task {
                guard !didAutoOpenThisSession else { return }
                didAutoOpenThisSession = true
                try? await Task.sleep(for: .milliseconds(450))
                await handleLaunchOrRequest()
            }
            .onReceive(NotificationCenter.default.publisher(for: .dockLiftOpenSettings)) { _ in
                Task { @MainActor in
                    await openSettingsFlow()
                }
            }
            .onReceive(NotificationCenter.default.publisher(for: .dockLiftOpenPermissionGate)) { _ in
                Task { @MainActor in
                    await openPermissionGateFlow()
                }
            }
    }

    @MainActor
    private func handleLaunchOrRequest() async {
        viewModel.syncMonitoring()
        if viewModel.hasAccessibilityPermission {
            await openSettingsFlow()
        } else {
            await openPermissionGateFlow()
        }
    }

    @MainActor
    private func openPermissionGateFlow() async {
        if NSApp.activationPolicy() != .regular {
            NSApp.setActivationPolicy(.regular)
            try? await Task.sleep(for: .milliseconds(80))
        }
        NSApp.activate(ignoringOtherApps: true)
        openWindow(id: OpenSettingsAction.permissionGateWindowID)
    }

    @MainActor
    private func openSettingsFlow() async {
        // Never open Settings without Accessibility.
        viewModel.syncMonitoring()
        guard viewModel.hasAccessibilityPermission else {
            await openPermissionGateFlow()
            return
        }

        if NSApp.activationPolicy() != .regular {
            NSApp.setActivationPolicy(.regular)
            try? await Task.sleep(for: .milliseconds(80))
        }

        NSApp.activate(ignoringOtherApps: true)
        openSettings()

        try? await Task.sleep(for: .milliseconds(180))
        OpenSettingsAction.focusSettingsWindow()
        NSApp.activate(ignoringOtherApps: true)
    }
}

/// Keeps the bootstrap window invisible and out of the window cycle.
private struct BootstrapWindowHider: NSViewRepresentable {
    func makeNSView(context: Context) -> NSView {
        let view = NSView(frame: .zero)
        DispatchQueue.main.async {
            guard let window = view.window else { return }
            window.alphaValue = 0
            window.ignoresMouseEvents = true
            window.collectionBehavior = [.transient, .ignoresCycle, .stationary]
            window.isExcludedFromWindowsMenu = true
            window.level = .normal
            window.orderOut(nil)
        }
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        DispatchQueue.main.async {
            nsView.window?.orderOut(nil)
        }
    }
}
