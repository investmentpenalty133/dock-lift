//
//  AboutSettingsView.swift
//  DockLift
//

import AppKit
import SwiftUI

struct AboutSettingsView: View {
    @EnvironmentObject private var viewModel: AppViewModel

    private var versionString: String {
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
        let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
        return "\(version) (\(build))"
    }

    /// Real DockLift app icon from the running bundle (AppIcon / .icns).
    private var appIcon: NSImage {
        let icon = NSWorkspace.shared.icon(forFile: Bundle.main.bundlePath)
        icon.size = NSSize(width: 128, height: 128)
        return icon
    }

    var body: some View {
        VStack(spacing: 14) {
            Image(nsImage: appIcon)
                .resizable()
                .interpolation(.high)
                .aspectRatio(contentMode: .fit)
                .frame(width: 72, height: 72)
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                .shadow(color: .black.opacity(0.12), radius: 6, y: 2)
                .padding(.top, 8)
                .accessibilityHidden(true)

            VStack(spacing: 0) {
                Text("DockLift")
                    .font(.title2.weight(.semibold))
                Text("Version \(versionString)")
                    .foregroundStyle(.secondary)
                    .fontWeight(.ultraLight)
                    .font(.system(size: 10))
            }
            
            Text(
                String(localized: "Click a Dock icon and DockLift brings that app’s most recently used window to the current Space, then activates it.")
            )
            .multilineTextAlignment(.center)
            .foregroundStyle(.secondary)
            .font(.callout)
            .frame(maxWidth: 320)
            .fixedSize(horizontal: false, vertical: true)

            Text("Requires macOS 14 or later")
                .font(.caption)
                .foregroundStyle(.tertiary)
                .padding(.top, 4)

            CheckForUpdatesButton()
                .buttonStyle(.bordered)
                .controlSize(.regular)
                .padding(.top, 8)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
        .padding(20)
    }
}
