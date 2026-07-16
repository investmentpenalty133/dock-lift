//
//  GeneralSettingsView.swift
//  DockLift
//

import SwiftUI

struct GeneralSettingsView: View {
    @EnvironmentObject private var viewModel: AppViewModel

    var body: some View {
        Form {
            Section {
                Toggle("Enable DockLift", isOn: $viewModel.isEnabled)
                Toggle("Only react to Dock clicks", isOn: $viewModel.onlyWhenDockClick)
                Toggle("Include minimized windows", isOn: $viewModel.includeMinimizedWindows)
            } header: {
                Text("Behavior")
            } footer: {
                Text(
                    viewModel.onlyWhenDockClick
                        ? "Windows are lifted when an app is activated via the Dock."
                        : "Windows are lifted on every application activation (including ⌘Tab)."
                )
            }

            Section {
                Toggle("Move windows to the Dock’s screen", isOn: $viewModel.moveToDockScreen)
                Toggle("Move windows to the current Space", isOn: $viewModel.preferMoveToCurrentSpace)
                Toggle(
                    "Use minimize fallback when needed",
                    isOn: $viewModel.useMinimizeFallback
                )
                .disabled(!viewModel.preferMoveToCurrentSpace)
            } header: {
                Text("Spaces & Displays")
            } footer: {
                Text(spaceFooterText)
            }

            Section {
                Toggle("Launch at login", isOn: $viewModel.launchAtLogin)
                Toggle("Show title next to menu bar icon", isOn: $viewModel.showStatusItemTitle)
            } header: {
                Text("Appearance & Startup")
            }
        }
        .formStyle(.grouped)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    private var spaceFooterText: String {
        var parts: [String] = []
        if viewModel.moveToDockScreen {
            parts.append(
                String(localized: "If the window is on another display, it is repositioned onto the screen where you clicked the Dock.")
            )
        }
        if !viewModel.preferMoveToCurrentSpace {
            parts.append(String(localized: "Space switching is left to macOS."))
        } else if viewModel.privateSpaceAPIAvailable {
            parts.append(
                String(localized: "Private Space APIs were found. Minimize fallback is used only when needed.")
            )
        } else {
            parts.append(
                String(localized: "No private Space APIs available; a public minimize → deminimize sequence may pull windows onto this Space.")
            )
        }
        return parts.joined(separator: " ")
    }
}
