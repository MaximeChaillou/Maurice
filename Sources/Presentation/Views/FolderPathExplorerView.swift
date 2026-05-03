import AppKit
import SwiftUI

/// Generic detail view for navigating a folder tree by relative path.
///
/// Renders a breadcrumb (`rootSegment` + one segment per path component) where
/// each path-segment popover lists its parent folder's children — subfolders
/// first, then `.md` notes (most recent first by filename). `.transcript`
/// files are hidden and only surface as a transcript toggle on their paired
/// note. Picking a file sibling navigates to it; picking a folder resolves to
/// its latest note.
struct FolderPathExplorerView: View {
    let rootURL: URL
    let rootSegment: BreadcrumbSegment
    @Binding var subpath: String
    var markdownTheme: MarkdownTheme = MarkdownTheme()
    var onActiveFileChange: ((URL?) -> Void)?

    @State private var contentsByDir: [URL: ScannedFolderContents] = [:]
    @State private var showTranscripts = false
    @State private var entryDeleteAction: EntryDeleteAction?
    @Environment(ErrorState.self) private var errorState: ErrorState?

    var body: some View {
        VStack(spacing: 0) {
            toolbar
            Divider().opacity(0.5)
            content
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .task(id: rootURL.path) {
            contentsByDir = [:]
            await loadVisibleLevels()
        }
        .task(id: subpath) { await loadVisibleLevels() }
        .onAppear { onActiveFileChange?(activeFileURL) }
        .onChange(of: subpath) {
            showTranscripts = false
            onActiveFileChange?(activeFileURL)
        }
        .onChange(of: showTranscripts) { onActiveFileChange?(activeFileURL) }
        .onReceive(NotificationCenter.default.publisher(for: .fileSystemDidChange)) { _ in
            contentsByDir = [:]
            Task { await loadVisibleLevels() }
        }
        .entryDeleteAlert(action: $entryDeleteAction) { action in
            handleDelete(action: action)
        }
    }

    // MARK: - Computed

    private var pathComponents: [String] {
        subpath.split(separator: "/", omittingEmptySubsequences: true).map(String.init)
    }

    private var activeFileURL: URL? {
        guard !subpath.isEmpty else { return nil }
        return rootURL.appendingPathComponent(subpath + ".md")
    }

    private var parentDirURL: URL {
        activeFileURL?.deletingLastPathComponent() ?? rootURL
    }

    private var activeEntry: MeetingDateEntry? {
        guard let activeFileURL, let activeBasename = pathComponents.last else { return nil }
        let date = DateFormatters.dayPOSIX.date(from: activeBasename) ?? Date.distantPast
        let transcriptURL = contentsByDir[parentDirURL]?.transcriptBasenames.contains(activeBasename) == true
            ? parentDirURL.appendingPathComponent(activeBasename + ".transcript")
            : nil
        let noteFile = FolderFile(id: activeFileURL, name: activeBasename, date: date, url: activeFileURL)
        let transcriptFile = transcriptURL.map {
            FolderFile(id: $0, name: activeBasename, date: date, url: $0)
        }
        return MeetingDateEntry(
            dateString: activeBasename,
            date: date,
            noteFile: noteFile,
            transcriptFile: transcriptFile
        )
    }

    // MARK: - Toolbar / content

    private var toolbar: some View {
        HStack(spacing: 6) {
            BreadcrumbBar(segments: buildBreadcrumb())
            Spacer(minLength: 8)
            if let entry = activeEntry {
                if entry.hasTranscript {
                    TranscriptPill(entry: entry, showTranscripts: $showTranscripts)
                }
                EntryMoreMenu(entry: entry, entryDeleteAction: $entryDeleteAction)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
    }

    @ViewBuilder
    private var content: some View {
        if let entry = activeEntry {
            DateEntryContentView(
                entry: entry,
                markdownTheme: markdownTheme,
                showTranscripts: $showTranscripts
            )
            .id(entry.noteFile?.id ?? entry.transcriptFile?.id)
        } else {
            ContentUnavailableView(
                "No file",
                systemImage: "doc.text",
                description: Text("Pick a file from the breadcrumb.")
            )
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    // MARK: - Breadcrumb building

    private func buildBreadcrumb() -> [BreadcrumbSegment] {
        var segments: [BreadcrumbSegment] = [rootSegment]
        var parentURL = rootURL
        var accumulated = ""
        let components = pathComponents
        for (idx, component) in components.enumerated() {
            let isLast = idx == components.count - 1
            let segmentURL = isLast
                ? parentURL.appendingPathComponent(component + ".md")
                : parentURL.appendingPathComponent(component)
            accumulated = accumulated.isEmpty ? component : accumulated + "/" + component
            let parentRel = relativePath(of: parentURL)
            segments.append(BreadcrumbSegment(
                id: "explorer-\(accumulated)",
                label: isLast ? component + ".md" : component,
                kind: isLast ? .file : .folder,
                revealURL: segmentURL,
                popoverTitle: nil,
                emptyMessage: String(localized: "No files"),
                groups: [BreadcrumbSiblingGroup(
                    id: "all",
                    title: nil,
                    siblings: siblings(in: parentURL, activeID: accumulated, parentRel: parentRel)
                )],
                onPick: { id in handlePick(siblingID: id) }
            ))
            parentURL = segmentURL
        }
        return segments
    }

    private func siblings(in dir: URL, activeID: String, parentRel: String) -> [BreadcrumbSibling] {
        guard let contents = contentsByDir[dir] else { return [] }
        var result: [BreadcrumbSibling] = []
        for folder in contents.subfolderNames {
            let pathFromRoot = parentRel.isEmpty ? folder : parentRel + "/" + folder
            result.append(BreadcrumbSibling(
                id: pathFromRoot + "/",
                label: folder,
                leading: .symbol("folder"),
                active: false
            ))
        }
        for basename in contents.noteBasenames {
            let pathFromRoot = parentRel.isEmpty ? basename : parentRel + "/" + basename
            result.append(BreadcrumbSibling(
                id: pathFromRoot,
                label: basename + ".md",
                leading: .symbol("doc.text"),
                active: pathFromRoot == activeID
            ))
        }
        return result
    }

    private func relativePath(of url: URL) -> String {
        let rootPath = rootURL.standardizedFileURL.path
        let path = url.standardizedFileURL.path
        if path == rootPath { return "" }
        let prefix = rootPath.hasSuffix("/") ? rootPath : rootPath + "/"
        if path.hasPrefix(prefix) {
            return String(path.dropFirst(prefix.count))
        }
        return ""
    }

    // MARK: - Pick handler

    private func handlePick(siblingID: String) {
        if siblingID.hasSuffix("/") {
            let folderRelative = String(siblingID.dropLast())
            let folderURL = rootURL.appendingPathComponent(folderRelative, isDirectory: true)
            Task {
                let contents = await loadFolderContents(at: folderURL)
                contentsByDir[folderURL] = contents
                if let latest = contents.noteBasenames.first {
                    subpath = folderRelative + "/" + latest
                }
            }
        } else {
            subpath = siblingID
        }
    }

    // MARK: - Loading

    private func loadVisibleLevels() async {
        var dirs: Set<URL> = [rootURL]
        var accumulated = rootURL
        for component in pathComponents.dropLast() {
            accumulated.appendPathComponent(component)
            dirs.insert(accumulated)
        }
        if let active = activeFileURL {
            dirs.insert(active.deletingLastPathComponent())
        }
        for dir in dirs where contentsByDir[dir] == nil {
            let contents = await loadFolderContents(at: dir)
            contentsByDir[dir] = contents
        }
    }

    private func loadFolderContents(at dir: URL) async -> ScannedFolderContents {
        await Task.detached { Self.scanContents(at: dir) }.value
    }

    // MARK: - Delete

    private func handleDelete(action: EntryDeleteAction) {
        removeFiles(for: action)
        Task { await refreshAfterDelete(action: action) }
    }

    private func removeFiles(for action: EntryDeleteAction) {
        let entry = action.entry
        let urls: [URL]
        switch action {
        case .note: urls = [entry.noteFile?.url].compactMap { $0 }
        case .transcript: urls = [entry.transcriptFile?.url].compactMap { $0 }
        case .both: urls = [entry.noteFile?.url, entry.transcriptFile?.url].compactMap { $0 }
        }
        for url in urls {
            do {
                try FileManager.default.removeItem(at: url)
            } catch {
                IssueLogger.log(.error, "Failed to delete entry", context: url.path, error: error)
                errorState?.show(String(localized: "Unable to delete: \(error.localizedDescription)"))
            }
        }
    }

    private func refreshAfterDelete(action: EntryDeleteAction) async {
        let parent = parentDirURL
        let contents = await loadFolderContents(at: parent)
        contentsByDir[parent] = contents
        if case .transcript = action { return }
        let parentRel = relativePath(of: parent)
        guard let next = contents.noteBasenames.first else {
            subpath = ""
            return
        }
        let newSubpath = parentRel.isEmpty ? next : parentRel + "/" + next
        if newSubpath != subpath { subpath = newSubpath }
    }
}

struct ScannedFolderContents: Equatable {
    let subfolderNames: [String]
    let noteBasenames: [String]
    let transcriptBasenames: Set<String>
}

// MARK: - Folder scanning + default resolution

extension FolderPathExplorerView {
    /// Scans `dir` for navigable contents: subfolders, `.md` notes (newest
    /// first by filename, `next.md` excluded), and `.transcript` basenames
    /// (used for transcript pairing — never listed as standalone entries).
    nonisolated static func scanContents(at dir: URL) -> ScannedFolderContents {
        let scanned = DirectoryScanner.scan(at: dir)
        let noteBasenames = scanned.files
            .filter { $0.url.pathExtension == "md" }
            .map { $0.url.deletingPathExtension().lastPathComponent }
            .filter { $0 != "next" }
            .sorted { $0.localizedStandardCompare($1) == .orderedDescending }
        let transcriptBasenames = Set(
            scanned.files
                .filter { $0.url.pathExtension == "transcript" }
                .map { $0.url.deletingPathExtension().lastPathComponent }
        )
        return ScannedFolderContents(
            subfolderNames: scanned.folders.map(\.name).sorted {
                $0.localizedStandardCompare($1) == .orderedAscending
            },
            noteBasenames: noteBasenames,
            transcriptBasenames: transcriptBasenames
        )
    }

    /// Resolves the default subpath inside `rootURL` for opening a person /
    /// folder. Walks `preferredFolders` in order, returning the latest `.md`
    /// in the first one that has any. Falls back to the latest `.md` at the
    /// root if no preferred folder produced a result.
    nonisolated static func resolveDefaultSubpath(
        in rootURL: URL,
        preferredFolders: [String] = []
    ) async -> String {
        await Task.detached {
            for folderName in preferredFolders {
                let folderURL = rootURL.appendingPathComponent(folderName, isDirectory: true)
                if let latest = scanContents(at: folderURL).noteBasenames.first {
                    return folderName + "/" + latest
                }
            }
            return scanContents(at: rootURL).noteBasenames.first ?? ""
        }.value
    }
}
