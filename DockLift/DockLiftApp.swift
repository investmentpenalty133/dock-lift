//
//  DockLiftApp.swift
//  DockLift
//
//  Menu bar utility entry point (SwiftUI App lifecycle).
//
//  Scene order matters for Settings bootstrap: the hidden Window that owns
//  `@Environment(\.openSettings)` must be declared *before* `Settings`.
//

import PermissionFlowStatusStore
import SwiftUI

@main
struct DockLiftApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @StateObject private var viewModel = AppViewModel()

    var body: some Scene {
        // 1) Hidden bootstrap window — provides openSettings / openWindow context.
        Window("DockLift Bootstrap", id: OpenSettingsAction.bootstrapWindowID) {
            SettingsBootstrapView()
                .environmentObject(viewModel)
                .environmentObject(viewModel.accessibility.statusStore)
        }
        .windowResizability(.contentSize)
        .defaultSize(width: 1, height: 1)
        .windowStyle(.hiddenTitleBar)
        .commandsRemoved()

        // 2) Permission gate — must authorize Accessibility before Settings.
        Window(String(localized: "Accessibility Required"), id: OpenSettingsAction.permissionGateWindowID) {
            PermissionGateView()
                .environmentObject(viewModel)
                .environmentObject(viewModel.accessibility.statusStore)
        }
        .windowResizability(.contentSize)
        .defaultSize(width: 460, height: 280)

        // 3) Status item — `.window` so Enable can use a switch control
        //    (`.menu` style only supports checkmark-style toggles).
        MenuBarExtra {
            MenuBarView()
                .environmentObject(viewModel)
                .environmentObject(viewModel.accessibility.statusStore)
        } label: {
            Label("DockLift", systemImage: menuBarSymbol)
        }
        .menuBarExtraStyle(.window)

        // 4) Settings scene (after bootstrap Window)
        Settings {
            SettingsView()
                .environmentObject(viewModel)
                .environmentObject(viewModel.accessibility.statusStore)
                .onDisappear {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                        let settingsStillOpen = OpenSettingsAction.findSettingsWindow()?.isVisible == true
                        let gateOpen = NSApp.windows.contains {
                            $0.isVisible && $0.identifier?.rawValue.contains(OpenSettingsAction.permissionGateWindowID) == true
                        }
                        if !settingsStillOpen && !gateOpen {
                            NSApp.setActivationPolicy(.accessory)
                        }
                    }
                }
        }
        .commands {
            // DockLift menu (when app is frontmost, e.g. Settings open)
            CommandGroup(after: .appInfo) {
                CheckForUpdatesButton()
            }
        }
    }

    private var menuBarSymbol: String {
        if !viewModel.hasAccessibilityPermission {
            return "exclamationmark.triangle.fill"
        }
        return "dock.rectangle"
    }
}
