//
//  SparkleUpdater.swift
//  DockLift
//
//  Thin wrapper around Sparkle 2 for manual “Check for Updates” and
//  automatic background checks (configured via Info.plist).
//

import AppKit
import Combine
import Sparkle
import SwiftUI

/// Owns `SPUStandardUpdaterController` for the app lifetime.
@MainActor
final class SparkleUpdater: ObservableObject {
    /// Shared instance used by About, menu bar, and the app Commands menu.
    static let shared = SparkleUpdater()

    private let controller: SPUStandardUpdaterController
    private var canCheckCancellable: AnyCancellable?

    @Published private(set) var canCheckForUpdates = false

    private init() {
        // Start the updater so scheduled checks run; UI still triggers manually.
        controller = SPUStandardUpdaterController(
            startingUpdater: true,
            updaterDelegate: nil,
            userDriverDelegate: nil
        )

        canCheckForUpdates = controller.updater.canCheckForUpdates
        canCheckCancellable = controller.updater
            .publisher(for: \.canCheckForUpdates)
            .receive(on: RunLoop.main)
            .sink { [weak self] value in
                self?.canCheckForUpdates = value
            }
    }

    /// Present Sparkle’s standard check-for-updates UI.
    func checkForUpdates() {
        // Menu-bar (LSUIElement) apps need activation so dialogs appear frontmost.
        if NSApp.activationPolicy() != .regular {
            NSApp.setActivationPolicy(.regular)
        }
        NSApp.activate(ignoringOtherApps: true)
        controller.checkForUpdates(nil)
    }
}

// MARK: - SwiftUI

/// Button that validates against Sparkle’s `canCheckForUpdates`.
struct CheckForUpdatesButton: View {
    @ObservedObject private var updater = SparkleUpdater.shared
    var title: LocalizedStringKey = "Check for Updates…"

    var body: some View {
        Button(title) {
            updater.checkForUpdates()
        }
        .disabled(!updater.canCheckForUpdates)
    }
}
