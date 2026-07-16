//
//  AdvancedSettingsView.swift
//  DockLift
//
//  Ignore-list management with manual entry, drag-and-drop of .app bundles,
//  Open panel, and picker of currently running apps.
//

import AppKit
import SwiftUI
import UniformTypeIdentifiers

struct AdvancedSettingsView: View {
    @EnvironmentObject private var viewModel: AppViewModel
    @State private var newBundleID = ""
    @State private var isDropTargeted = false
    @State private var dropError: String?
    @State private var dropHint: String?

    var body: some View {
        Form {
            Section {
                if viewModel.ignoredBundleIdentifiers.isEmpty {
                    Text("No ignored applications.")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(viewModel.ignoredBundleIdentifiers, id: \.self) { bundleID in
                        ignoredAppRow(bundleID)
                    }
                }

                HStack {
                    TextField("Bundle identifier", text: $newBundleID)
                        .textFieldStyle(.roundedBorder)
                        .font(.system(.body, design: .monospaced))
                        .onSubmit(addBundleID)
                    Button("Add") {
                        addBundleID()
                    }
                    .disabled(newBundleID.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }

                // AppKit-backed drop target (reliable inside Form / Settings).
                AppDropTargetView(
                    isTargeted: $isDropTargeted,
                    onURLs: { urls in
                        ingestDroppedURLs(urls)
                    }
                ) {
                    VStack(spacing: 8) {
                        Image(systemName: "square.and.arrow.down.on.square")
                            .font(.title2)
                            .foregroundStyle(isDropTargeted ? Color.accentColor : Color.secondary)
                        Text("Drop an app here")
                            .font(.callout.weight(.medium))
                        Text("or choose one with the buttons below")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity, minHeight: 88)
                    .padding(.vertical, 12)
                    .background(
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .strokeBorder(
                                isDropTargeted ? Color.accentColor : Color.secondary.opacity(0.35),
                                style: StrokeStyle(lineWidth: 1.5, dash: [6, 4])
                            )
                            .background(
                                RoundedRectangle(cornerRadius: 10, style: .continuous)
                                    .fill(isDropTargeted ? Color.accentColor.opacity(0.08) : Color.clear)
                            )
                    )
                }
                .frame(maxWidth: .infinity, minHeight: 100)
                .padding(.top, 4)

                HStack(spacing: 12) {
                    Button {
                        chooseApplicationWithOpenPanel()
                    } label: {
                        Label("Choose App…", systemImage: "folder")
                    }

                    Menu {
                        ForEach(runningAppsForPicker, id: \.processIdentifier) { app in
                            Button {
                                addApp(app)
                            } label: {
                                Label {
                                    Text(app.localizedName ?? app.bundleIdentifier ?? "App")
                                } icon: {
                                    if let icon = app.icon {
                                        Image(nsImage: icon)
                                            .resizable()
                                    } else {
                                        Image(systemName: "app")
                                    }
                                }
                            }
                        }
                    } label: {
                        Label("Running Apps", systemImage: "app.dashed")
                    }
                    .disabled(runningAppsForPicker.isEmpty)
                    .help("Pick a currently running application")
                }

                if let dropHint {
                    Text(dropHint)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                if let dropError {
                    Text(dropError)
                        .font(.caption)
                        .foregroundStyle(.red)
                }
            } header: {
                Text("Ignored Applications")
            } footer: {
                Text("DockLift will not lift windows for these apps. Drag an .app here, choose one from disk, pick a running app, or type a bundle identifier. Finder and DockLift are ignored by default.")
            }

            Section {
                LabeledContent("Monitor") {
                    Text(viewModel.monitor.isRunning ? "Running" : "Stopped")
                }
                LabeledContent("Dock orientation") {
                    Text(localizedDockOrientation)
                }
            } header: {
                Text("Diagnostics")
            }
        }
        .formStyle(.grouped)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        // SwiftUI drop as a secondary path (some hosts prefer this).
        .onDrop(of: [.fileURL], isTargeted: $isDropTargeted) { providers in
            handleSwiftUIDrop(providers: providers)
        }
    }

    // MARK: - Rows

    @ViewBuilder
    private func ignoredAppRow(_ bundleID: String) -> some View {
        let info = AppBundleResolver.info(for: bundleID)
        HStack(spacing: 10) {
            if let icon = info.icon {
                Image(nsImage: icon)
                    .resizable()
                    .frame(width: 24, height: 24)
                    .cornerRadius(4)
            } else {
                Image(systemName: "app.dashed")
                    .frame(width: 24, height: 24)
                    .foregroundStyle(.secondary)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(info.displayName)
                Text(bundleID)
                    .font(.system(.caption, design: .monospaced))
                    .foregroundStyle(.secondary)
                    .textSelection(.enabled)
            }
            Spacer()
            Button(role: .destructive) {
                viewModel.removeIgnoredBundleID(bundleID)
            } label: {
                Image(systemName: "minus.circle.fill")
            }
            .buttonStyle(.borderless)
            .help("Remove")
        }
    }

    // MARK: - Actions

    private func addBundleID() {
        dropError = nil
        dropHint = nil
        let id = newBundleID.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !id.isEmpty else { return }
        viewModel.addIgnoredBundleID(id)
        newBundleID = ""
    }

    private func addBundleIDFromURL(_ url: URL) {
        dropError = nil
        dropHint = nil
        let accessed = url.startAccessingSecurityScopedResource()
        defer {
            if accessed { url.stopAccessingSecurityScopedResource() }
        }

        guard let bundleID = AppBundleResolver.bundleIdentifier(from: url) else {
            dropError = String(localized: "Could not read a bundle identifier from that item.")
            return
        }

        let before = Set(viewModel.ignoredBundleIdentifiers)
        viewModel.addIgnoredBundleID(bundleID)
        if before.contains(bundleID) {
            dropHint = String(
                format: String(localized: "%@ is already ignored."),
                bundleID
            )
        } else {
            let name = AppBundleResolver.info(for: bundleID).displayName
            dropHint = String(
                format: String(localized: "Added %@"),
                name
            )
        }
        newBundleID = ""
    }

    private func addApp(_ app: NSRunningApplication) {
        dropError = nil
        dropHint = nil
        guard let bundleID = app.bundleIdentifier else {
            dropError = String(localized: "That application has no bundle identifier.")
            return
        }
        viewModel.addIgnoredBundleID(bundleID)
        dropHint = String(
            format: String(localized: "Added %@"),
            app.localizedName ?? bundleID
        )
    }

    private func ingestDroppedURLs(_ urls: [URL]) {
        guard !urls.isEmpty else {
            dropError = String(localized: "Could not read a bundle identifier from that item.")
            return
        }
        for url in urls {
            addBundleIDFromURL(url)
        }
    }

    private func chooseApplicationWithOpenPanel() {
        dropError = nil
        dropHint = nil
        let panel = NSOpenPanel()
        panel.canChooseFiles = true
        panel.canChooseDirectories = true // .app is a package / directory
        panel.allowsMultipleSelection = true
        panel.treatsFilePackagesAsDirectories = false
        panel.title = String(localized: "Choose Application")
        panel.message = String(localized: "Select one or more apps to ignore.")
        panel.prompt = String(localized: "Add")
        panel.directoryURL = URL(fileURLWithPath: "/Applications")
        panel.allowedContentTypes = [.application, .applicationBundle]

        panel.begin { response in
            guard response == .OK else { return }
            DispatchQueue.main.async {
                ingestDroppedURLs(panel.urls)
            }
        }
    }

    /// Secondary SwiftUI drop path.
    private func handleSwiftUIDrop(providers: [NSItemProvider]) -> Bool {
        guard !providers.isEmpty else { return false }
        for provider in providers {
            loadURL(from: provider) { url in
                DispatchQueue.main.async {
                    if let url {
                        addBundleIDFromURL(url)
                    } else {
                        dropError = String(localized: "Could not read a bundle identifier from that item.")
                    }
                }
            }
        }
        return true
    }

    private func loadURL(from provider: NSItemProvider, completion: @escaping (URL?) -> Void) {
        // 1) Modern path
        if provider.canLoadObject(ofClass: URL.self) {
            _ = provider.loadObject(ofClass: URL.self) { object, _ in
                completion(object)
            }
            return
        }

        // 2) Classic file-url item
        let typeID = UTType.fileURL.identifier
        if provider.hasItemConformingToTypeIdentifier(typeID) {
            provider.loadItem(forTypeIdentifier: typeID, options: nil) { item, _ in
                completion(Self.url(fromDropItem: item))
            }
            return
        }

        // 3) public.url fallback
        if provider.hasItemConformingToTypeIdentifier(UTType.url.identifier) {
            provider.loadItem(forTypeIdentifier: UTType.url.identifier, options: nil) { item, _ in
                completion(Self.url(fromDropItem: item))
            }
            return
        }

        completion(nil)
    }

    private static func url(fromDropItem item: NSSecureCoding?) -> URL? {
        if let url = item as? URL {
            return url
        }
        if let data = item as? Data {
            if let url = URL(dataRepresentation: data, relativeTo: nil) {
                return url
            }
            if let str = String(data: data, encoding: .utf8) {
                return URL(fileURLWithPath: str.replacingOccurrences(of: "file://", with: ""))
                    .standardizedFileURL
            }
        }
        if let str = item as? String {
            if let url = URL(string: str), url.isFileURL {
                return url
            }
            return URL(fileURLWithPath: str)
        }
        if let nsurl = item as? NSURL {
            return nsurl as URL
        }
        return nil
    }

    private var runningAppsForPicker: [NSRunningApplication] {
        let ignored = Set(viewModel.ignoredBundleIdentifiers)
        let selfID = Bundle.main.bundleIdentifier
        return NSWorkspace.shared.runningApplications
            .filter { app in
                app.activationPolicy == .regular
                    && app.bundleIdentifier != nil
                    && app.bundleIdentifier != selfID
                    && !(ignored.contains(app.bundleIdentifier ?? ""))
            }
            .sorted {
                ($0.localizedName ?? "").localizedCaseInsensitiveCompare($1.localizedName ?? "")
                    == .orderedAscending
            }
    }

    private var localizedDockOrientation: String {
        switch DockGeometry.orientation {
        case .bottom: return String(localized: "Bottom")
        case .left: return String(localized: "Left")
        case .right: return String(localized: "Right")
        }
    }
}

// MARK: - AppKit drop target (works inside Form / Settings)

/// Hosts an NSView that registers for file drags — more reliable than SwiftUI `onDrop`
/// when embedded in a `Form` / Settings scene.
private struct AppDropTargetView<Content: View>: NSViewRepresentable {
    @Binding var isTargeted: Bool
    var onURLs: ([URL]) -> Void
    @ViewBuilder var content: () -> Content

    func makeNSView(context: Context) -> DropHostingView<Content> {
        let view = DropHostingView(rootView: content())
        view.onTargetedChange = { targeted in
            DispatchQueue.main.async { isTargeted = targeted }
        }
        view.onURLs = { urls in
            DispatchQueue.main.async { onURLs(urls) }
        }
        return view
    }

    func updateNSView(_ nsView: DropHostingView<Content>, context: Context) {
        nsView.rootView = content()
        nsView.onTargetedChange = { targeted in
            DispatchQueue.main.async { isTargeted = targeted }
        }
        nsView.onURLs = { urls in
            DispatchQueue.main.async { onURLs(urls) }
        }
    }
}

private final class DropHostingView<Content: View>: NSView {
    var onTargetedChange: ((Bool) -> Void)?
    var onURLs: (([URL]) -> Void)?

    private let hosting: NSHostingView<Content>

    var rootView: Content {
        get { hosting.rootView }
        set { hosting.rootView = newValue }
    }

    init(rootView: Content) {
        hosting = NSHostingView(rootView: rootView)
        super.init(frame: .zero)
        hosting.translatesAutoresizingMaskIntoConstraints = false
        addSubview(hosting)
        NSLayoutConstraint.activate([
            hosting.leadingAnchor.constraint(equalTo: leadingAnchor),
            hosting.trailingAnchor.constraint(equalTo: trailingAnchor),
            hosting.topAnchor.constraint(equalTo: topAnchor),
            hosting.bottomAnchor.constraint(equalTo: bottomAnchor),
        ])
        registerForDraggedTypes([
            .fileURL,
            NSPasteboard.PasteboardType(rawValue: "public.file-url"),
            NSPasteboard.PasteboardType(rawValue: "NSFilenamesPboardType"),
        ])
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError() }

    override func draggingEntered(_ sender: NSDraggingInfo) -> NSDragOperation {
        guard Self.containsApplicationDrop(sender) else { return [] }
        onTargetedChange?(true)
        return .copy
    }

    override func draggingUpdated(_ sender: NSDraggingInfo) -> NSDragOperation {
        Self.containsApplicationDrop(sender) ? .copy : []
    }

    override func draggingExited(_ sender: NSDraggingInfo?) {
        onTargetedChange?(false)
    }

    override func prepareForDragOperation(_ sender: NSDraggingInfo) -> Bool {
        Self.containsApplicationDrop(sender)
    }

    override func performDragOperation(_ sender: NSDraggingInfo) -> Bool {
        onTargetedChange?(false)
        let urls = Self.urls(from: sender)
        guard !urls.isEmpty else { return false }
        onURLs?(urls)
        return true
    }

    override func concludeDragOperation(_ sender: NSDraggingInfo?) {
        onTargetedChange?(false)
    }

    private static func containsApplicationDrop(_ sender: NSDraggingInfo) -> Bool {
        let urls = urls(from: sender)
        if urls.isEmpty { return false }
        return urls.contains { AppBundleResolver.looksLikeApplication($0) }
    }

    private static func urls(from sender: NSDraggingInfo) -> [URL] {
        let pb = sender.draggingPasteboard
        var result: [URL] = []

        // Modern file URL reading
        if let urls = pb.readObjects(forClasses: [NSURL.self], options: [
            .urlReadingFileURLsOnly: true,
        ]) as? [URL] {
            result.append(contentsOf: urls)
        }

        // Legacy filenames
        if let filenames = pb.propertyList(forType: NSPasteboard.PasteboardType("NSFilenamesPboardType")) as? [String] {
            result.append(contentsOf: filenames.map { URL(fileURLWithPath: $0) })
        }

        // public.file-url items
        if let items = pb.pasteboardItems {
            for item in items {
                if let str = item.string(forType: .fileURL),
                   let url = URL(string: str)
                {
                    result.append(url)
                }
            }
        }

        // Deduplicate
        var seen = Set<String>()
        return result.filter { url in
            let key = url.standardizedFileURL.path
            if seen.contains(key) { return false }
            seen.insert(key)
            return true
        }
    }
}

// MARK: - Bundle resolution helpers

enum AppBundleResolver {
    struct Info {
        var displayName: String
        var icon: NSImage?
    }

    static func looksLikeApplication(_ url: URL) -> Bool {
        let path = url.standardizedFileURL.path
        if path.hasSuffix(".app") { return true }
        if let values = try? url.resourceValues(forKeys: [.typeIdentifierKey, .isApplicationKey]) {
            if values.isApplication == true { return true }
            if let type = values.typeIdentifier,
               UTType(type)?.conforms(to: .application) == true
            {
                return true
            }
        }
        // Allow drop of any package that has an Info.plist with CFBundleIdentifier.
        return bundleIdentifier(from: url) != nil
    }

    static func bundleIdentifier(from url: URL) -> String? {
        var resolved = url.standardizedFileURL

        // Resolve aliases / symlinks.
        if let values = try? resolved.resourceValues(forKeys: [.isAliasFileKey]),
           values.isAliasKeyTrue
        {
            if let original = try? URL(resolvingAliasFileAt: resolved) {
                resolved = original.standardizedFileURL
            }
        }
        resolved = resolved.resolvingSymlinksInPath()

        // Walk up to enclosing .app if a file inside the package was dropped.
        if let appURL = enclosingApplicationURL(from: resolved) {
            resolved = appURL
        }

        if let bundle = Bundle(url: resolved),
           let id = bundle.bundleIdentifier,
           !id.isEmpty
        {
            return id
        }

        // Read Info.plist directly (more resilient when Bundle init fails).
        let infoPlist = resolved.appendingPathComponent("Contents/Info.plist")
        if let dict = NSDictionary(contentsOf: infoPlist) as? [String: Any],
           let id = dict["CFBundleIdentifier"] as? String,
           !id.isEmpty
        {
            return id
        }

        return nil
    }

    private static func enclosingApplicationURL(from url: URL) -> URL? {
        var current = url
        for _ in 0..<8 {
            if current.pathExtension == "app" { return current }
            let parent = current.deletingLastPathComponent()
            if parent.path == current.path { break }
            current = parent
        }
        return nil
    }

    static func info(for bundleID: String) -> Info {
        if let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID) {
            let name = FileManager.default.displayName(atPath: url.path)
            let icon = NSWorkspace.shared.icon(forFile: url.path)
            icon.size = NSSize(width: 32, height: 32)
            return Info(displayName: name, icon: icon)
        }
        return Info(displayName: bundleID, icon: nil)
    }
}

private extension URLResourceValues {
    var isAliasKeyTrue: Bool { isAliasFile == true }
}
