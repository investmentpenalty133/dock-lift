//
//  PermissionsSettingsView.swift
//  DockLift
//

import PermissionFlow
import PermissionFlowStatusStore
import SwiftUI

struct PermissionsSettingsView: View {
    @EnvironmentObject private var viewModel: AppViewModel
    @EnvironmentObject private var permissionStatusStore: PermissionFlowStatusStore

    var body: some View {
        Form {
            Section {
                LabeledContent("Accessibility") {
                    statusLabel
                }

                Text("DockLift needs Accessibility access to read window lists and raise windows belonging to other apps.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)

                // PermissionFlow replaces the old AX prompt / System Settings deep link buttons.
                PermissionFlowButton(
                    title: "Grant Accessibility…",
                    pane: .accessibility,
                    suggestedAppURLs: [Bundle.main.bundleURL]
                )

                if viewModel.hasAccessibilityPermission {
                    Text("Accessibility is granted. DockLift can inspect and control windows.")
                        .font(.callout)
                        .foregroundStyle(.secondary)

                    Button("Recheck") {
                        viewModel.syncMonitoring()
                    }
                }
            } header: {
                Text("System Permissions")
            }

            Section {
                LabeledContent("Space private API") {
                    Text(viewModel.privateSpaceAPIAvailable ? "Available" : "Unavailable")
                        .foregroundStyle(
                            viewModel.privateSpaceAPIAvailable ? Color.secondary : Color.orange
                        )
                }
                Text(
                    """
                    Moving a window onto the active Mission Control Space has no public API. \
                    DockLift optionally loads undocumented SkyLight symbols at runtime and falls \
                    back to Accessibility-only behaviour when they are missing.
                    """
                )
                .font(.callout)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            } header: {
                Text("Capabilities")
            }
        }
        .formStyle(.grouped)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .onAppear {
            viewModel.syncMonitoring()
        }
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
            viewModel.syncMonitoring()
        }
    }

    @ViewBuilder
    private var statusLabel: some View {
        let state = permissionStatusStore.state(for: .accessibility)
        HStack(spacing: 8) {
            Image(systemName: PermissionFlowButtonState.make(from: state).systemImage)
                .foregroundStyle(state == .granted ? .green : .orange)
            Text(statusTitle(for: state))
        }
    }

    private func statusTitle(for state: PermissionAuthorizationState) -> String {
        switch state {
        case .granted:
            return String(localized: "Granted")
        case .notGranted:
            return String(localized: "Not granted")
        case .checking:
            return String(localized: "Checking…")
        case .unknown:
            return String(localized: "Unknown")
        }
    }
}
