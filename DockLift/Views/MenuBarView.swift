//
//  MenuBarView.swift
//  DockLift
//
//  Menu content for the MenuBarExtra status item (`.menu` style).
//

import AppKit
import SwiftUI

struct MenuBarView: View {
    @EnvironmentObject private var viewModel: AppViewModel

    var body: some View {
        Toggle("Enable DockLift", isOn: $viewModel.isEnabled)
            .disabled(!viewModel.hasAccessibilityPermission)

        Divider()

        if viewModel.hasAccessibilityPermission {
            Text("Accessibility: Granted")
        } else {
            Button("Grant Accessibility…") {
                viewModel.requestAccessibility()
            }
        }

        Text(viewModel.monitor.isRunning ? "Status: Monitoring" : "Status: Paused")

        if !viewModel.monitor.lastEventDescription.isEmpty {
            Text(viewModel.monitor.lastEventDescription)
                .foregroundStyle(.secondary)
                .lineLimit(2)
        }

        Divider()

        Button("Settings…") {
            // Gate: no Accessibility → permission window first.
            viewModel.openSettingsOrPermissionGate()
        }
        .keyboardShortcut(",", modifiers: .command)

        CheckForUpdatesButton()

        Divider()

        Button("Quit DockLift") {
            NSApplication.shared.terminate(nil)
        }
        .keyboardShortcut("q", modifiers: .command)
    }
}
