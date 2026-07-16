//
//  ScreenCoordinates.swift
//  DockLift
//
//  Converts between AppKit (bottom-left origin) and Accessibility / Quartz
//  (top-left origin) global coordinates across multiple displays.
//

import AppKit
import CoreGraphics
import Foundation

/// Multi-display coordinate helpers.
enum ScreenCoordinates {
    /// The screen whose frame origin is `(0, 0)` — AppKit / CG global origin.
    static var primaryScreen: NSScreen? {
        NSScreen.screens.first { $0.frame.origin == .zero } ?? NSScreen.screens.first
    }

    /// Stable display id for an `NSScreen`.
    static func displayID(of screen: NSScreen) -> CGDirectDisplayID {
        let key = NSDeviceDescriptionKey("NSScreenNumber")
        if let number = screen.deviceDescription[key] as? NSNumber {
            return CGDirectDisplayID(number.uint32Value)
        }
        return kCGNullDirectDisplay
    }

    static func screen(displayID id: CGDirectDisplayID) -> NSScreen? {
        NSScreen.screens.first { displayID(of: $0) == id }
    }

    static func screen(containingAppKitPoint point: CGPoint) -> NSScreen? {
        NSScreen.screens.first { NSMouseInRect(point, $0.frame, false) }
    }

    /// Accessibility `kAXPosition` uses global coordinates with origin at the
    /// **top-left** of the primary display (y grows downward).
    /// AppKit uses origin at the **bottom-left** of the primary display (y grows up).
    static func axTopLeft(fromAppKitBottomLeft origin: CGPoint, height: CGFloat) -> CGPoint {
        guard let primary = primaryScreen else {
            return CGPoint(x: origin.x, y: origin.y)
        }
        return CGPoint(
            x: origin.x,
            y: primary.frame.maxY - origin.y - height
        )
    }

    static func appKitBottomLeft(fromAXTopLeft origin: CGPoint, height: CGFloat) -> CGPoint {
        guard let primary = primaryScreen else {
            return CGPoint(x: origin.x, y: origin.y)
        }
        return CGPoint(
            x: origin.x,
            y: primary.frame.maxY - origin.y - height
        )
    }

    static func appKitFrame(axTopLeft: CGPoint, size: CGSize) -> CGRect {
        let origin = appKitBottomLeft(fromAXTopLeft: axTopLeft, height: size.height)
        return CGRect(origin: origin, size: size)
    }

    /// Screen that currently hosts most of the window (by intersection area).
    static func screen(hostingAXTopLeft position: CGPoint, size: CGSize) -> NSScreen? {
        let frame = appKitFrame(axTopLeft: position, size: size)
        var best: (NSScreen, CGFloat)?
        for screen in NSScreen.screens {
            let inter = frame.intersection(screen.frame)
            guard !inter.isNull, !inter.isEmpty else { continue }
            let area = inter.width * inter.height
            if best == nil || area > best!.1 {
                best = (screen, area)
            }
        }
        return best?.0
    }

    /// Places a window of `size` centered inside `screen.visibleFrame`,
    /// clamped so it remains fully (or as fully as possible) on that display.
    static func centeredAppKitOrigin(size: CGSize, on screen: NSScreen) -> (origin: CGPoint, size: CGSize) {
        let visible = screen.visibleFrame
        let width = min(max(size.width, 200), visible.width)
        let height = min(max(size.height, 120), visible.height)
        let origin = CGPoint(
            x: visible.midX - width / 2,
            y: visible.midY - height / 2
        )
        return (origin, CGSize(width: width, height: height))
    }

    /// Preserves the window’s relative position within its current screen when
    /// moving to `target`, falling back to centering when geometry is unknown.
    static func relocatedAppKitFrame(
        currentAXTopLeft: CGPoint?,
        currentSize: CGSize?,
        from sourceScreen: NSScreen?,
        to target: NSScreen
    ) -> (origin: CGPoint, size: CGSize) {
        let fallbackSize = currentSize ?? CGSize(width: 900, height: 600)

        guard
            let currentAXTopLeft,
            let currentSize,
            let sourceScreen
        else {
            return centeredAppKitOrigin(size: fallbackSize, on: target)
        }

        let currentFrame = appKitFrame(axTopLeft: currentAXTopLeft, size: currentSize)
        let sourceVisible = sourceScreen.visibleFrame
        let targetVisible = target.visibleFrame

        // Normalised offset of the window’s top-leading corner inside the source visible frame.
        let relX: CGFloat
        let relY: CGFloat
        if sourceVisible.width > 1 {
            relX = (currentFrame.minX - sourceVisible.minX) / sourceVisible.width
        } else {
            relX = 0.1
        }
        if sourceVisible.height > 1 {
            // AppKit: measure from top of visible area.
            let sourceTop = sourceVisible.maxY
            relY = (sourceTop - currentFrame.maxY) / sourceVisible.height
        } else {
            relY = 0.1
        }

        let width = min(max(currentSize.width, 200), targetVisible.width)
        let height = min(max(currentSize.height, 120), targetVisible.height)

        var originX = targetVisible.minX + relX * targetVisible.width
        var originY = targetVisible.maxY - relY * targetVisible.height - height

        // Clamp fully inside the target visible frame when possible.
        originX = min(max(originX, targetVisible.minX), targetVisible.maxX - width)
        originY = min(max(originY, targetVisible.minY), targetVisible.maxY - height)

        return (CGPoint(x: originX, y: originY), CGSize(width: width, height: height))
    }
}
