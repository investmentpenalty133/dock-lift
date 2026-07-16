//
//  ManagedWindow.swift
//  DockLift
//
//  Lightweight description of an application window discovered via Accessibility.
//

import AppKit
import ApplicationServices
import CoreGraphics
import Foundation

/// A window managed by DockLift, backed by an `AXUIElement`.
struct ManagedWindow: Identifiable, Hashable {
    let id: String
    let element: AXUIElement
    let processIdentifier: pid_t
    let title: String
    let role: String
    let subrole: String?
    let isMinimized: Bool
    let isHidden: Bool
    /// Quartz window id when available (`_AXUIElementGetWindow`). `0` if unknown.
    let cgWindowID: CGWindowID
    /// Whether the window currently appears on-screen (current Space / visible).
    let isOnScreen: Bool
    /// AX top-left position when available.
    let position: CGPoint?
    let size: CGSize?
    /// Relative front-to-back ranking (lower is closer to front).
    let zOrder: Int
    /// Display that currently hosts most of this window, if known.
    let displayID: CGDirectDisplayID?

    var isLikelyOnOtherSpace: Bool {
        !isOnScreen && !isMinimized && !isHidden
    }

    /// `true` when the window’s geometry lives primarily on `screen`.
    func isLocated(on screen: NSScreen) -> Bool {
        if let displayID {
            return displayID == ScreenCoordinates.displayID(of: screen)
        }
        guard let position, let size else { return false }
        guard let host = ScreenCoordinates.screen(hostingAXTopLeft: position, size: size) else {
            return false
        }
        return ScreenCoordinates.displayID(of: host) == ScreenCoordinates.displayID(of: screen)
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }

    static func == (lhs: ManagedWindow, rhs: ManagedWindow) -> Bool {
        lhs.id == rhs.id
    }
}
