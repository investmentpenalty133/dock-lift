//
//  AppDelegate.swift
//  DockLift
//
//  Starts as an accessory (menu-bar) app. Settings bootstrap promotes to
//  `.regular` while the Settings window is open.
//

import AppKit

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        // Menu-bar agent by default; Settings flow switches to .regular temporarily.
        NSApp.setActivationPolicy(.accessory)

        // Bootstrap decides: permission gate first, Settings only when trusted.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
            OpenSettingsAction.request()
        }
    }

    /// Dock icon click for an already-running DockLift (Settings often open on another display).
    /// Always re-show preferences on the screen where the user clicked.
    func applicationShouldHandleReopen(
        _ sender: NSApplication,
        hasVisibleWindows flag: Bool
    ) -> Bool {
        // Regardless of whether a window is already visible (possibly on another
        // monitor), pull our Settings / permission UI to the Dock click screen.
        OpenSettingsAction.bringOwnWindowsToDockScreen()
        return true
    }
}
