//
//  PermissionGateView.swift
//  DockLift
//
//  Shown when Accessibility is not granted. User must authorize before Settings.
//

import PermissionFlow
import PermissionFlowStatusStore
import SwiftUI

struct PermissionGateView: View {
    @EnvironmentObject private var viewModel: AppViewModel
    @EnvironmentObject private var permissionStatusStore: PermissionFlowStatusStore
    @Environment(\.dismissWindow) private var dismissWindow

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 12) {
                Image(systemName: "hand.raised.fill")
                    .font(.system(size: 28))
                    .foregroundStyle(.tint)
                    .symbolRenderingMode(.hierarchical)
                VStack(alignment: .leading, spacing: 4) {
                    Text("Accessibility Required")
                        .font(.title2.weight(.semibold))
                    Text("DockLift needs Accessibility before you can open Settings or lift windows.")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            Text("Grant Accessibility, then drag DockLift into the list if prompted. After authorization, Settings will open automatically.")
                .font(.callout)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            PermissionFlowButton(
                title: "Grant Accessibility…",
                pane: .accessibility,
                suggestedAppURLs: [Bundle.main.bundleURL]
            )
            .controlSize(.large)

            HStack {
                Spacer()
                Button("Later") {
                    dismissWindow(id: OpenSettingsAction.permissionGateWindowID)
                    NSApp.setActivationPolicy(.accessory)
                }
                .keyboardShortcut(.cancelAction)
            }
        }
        .padding(24)
        .frame(width: 440)
        .onAppear {
            permissionStatusStore.refresh(.accessibility)
            viewModel.syncMonitoring()
        }
        .onChange(of: permissionStatusStore.state(for: .accessibility)) { _, newState in
            handleAuthorizationState(newState)
        }
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
            permissionStatusStore.refresh(.accessibility)
            viewModel.syncMonitoring()
            handleAuthorizationState(permissionStatusStore.state(for: .accessibility))
        }
    }

    private func handleAuthorizationState(_ state: PermissionAuthorizationState) {
        guard state == .granted else { return }
        viewModel.syncMonitoring()
        dismissWindow(id: OpenSettingsAction.permissionGateWindowID)
        // Proceed to Settings only after permission is granted.
        OpenSettingsAction.requestSettings(force: true)
    }
}

#Preview {
    let store = PermissionFlowStatusStore(panes: [.accessibility])
    return PermissionGateView()
        .environmentObject(AppViewModel())
        .environmentObject(store)
}
