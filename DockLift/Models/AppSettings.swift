//
//  AppSettings.swift
//  DockLift
//
//  User-facing preferences persisted via UserDefaults / AppStorage keys.
//

import Foundation
import SwiftUI

/// Strongly typed keys and defaults for DockLift preferences.
enum AppSettings {
    enum Key {
        static let isEnabled = "isEnabled"
        static let onlyWhenDockClick = "onlyWhenDockClick"
        static let includeMinimizedWindows = "includeMinimizedWindows"
        static let preferMoveToCurrentSpace = "preferMoveToCurrentSpace"
        static let moveToDockScreen = "moveToDockScreen"
        static let useMinimizeFallback = "useMinimizeFallback"
        static let launchAtLogin = "launchAtLogin"
        static let showStatusItemTitle = "showStatusItemTitle"
        static let ignoredBundleIdentifiers = "ignoredBundleIdentifiers"
    }

    static let defaults: [String: Any] = [
        Key.isEnabled: true,
        Key.onlyWhenDockClick: true,
        Key.includeMinimizedWindows: true,
        Key.preferMoveToCurrentSpace: true,
        Key.moveToDockScreen: true,
        Key.useMinimizeFallback: true,
        Key.launchAtLogin: false,
        Key.showStatusItemTitle: false,
        Key.ignoredBundleIdentifiers: [
            "com.apple.finder",
            Bundle.main.bundleIdentifier ?? "com.wangchujiang.docklift"
        ] as [String]
    ]

    static func registerDefaults() {
        UserDefaults.standard.register(defaults: defaults)
    }
}
