import Foundation
import Observation

@Observable
@MainActor
final class FolderContentViewModel {
    private(set) var directory: URL

    private(set) var folders: [FolderItem] = []
    var selectedFolder: String?
    var selectedFile: URL?
    var fileIndex: Int = 0
    var isAddingFolder = false
    var newFolderName = ""
    var meetingConfig: MeetingConfig = MeetingConfig()
    var errorMessage: String?

    var currentFolder: FolderItem? {
        guard let name = selectedFolder else { return nil }
        return folders.first { $0.name == name }
    }

    init(directory: URL) {
        self.directory = directory
    }

    func resetDirectory(_ newDirectory: URL) {
        directory = newDirectory
        selectedFolder = nil
        selectedFile = nil
        folders = []
        loadFolders()
    }

    func loadFolders() {
        Task {
            await loadFoldersAsync()
        }
    }

    private func loadFoldersAsync() async {
        let dir = directory
        let result = await Task.detached {
            let fm = FileManager.default
            do {
                try fm.createDirectory(at: dir, withIntermediateDirectories: true)
            } catch {
                IssueLogger.log(.warning, "Failed to create directory", context: dir.path, error: error)
            }

            let contents = DirectoryScanner.scan(at: dir)
            let storage = FileTranscriptionStorage()

            return contents.folders.map { folder in
                let files = Self.scanFiles(in: folder.url)
                let dateEntries = Self.scanDateEntries(in: folder.url, storage: storage)
                let icon = MeetingConfig.load(from: folder.url).icon
                return FolderItem(name: folder.name, url: folder.url, files: files, dateEntries: dateEntries, icon: icon)
            }
            .sorted { (a: FolderItem, b: FolderItem) in
                a.name.localizedCaseInsensitiveCompare(b.name) == .orderedAscending
            }
        }.value

        folders = result
    }

    func createFolder() {
        let name = newFolderName.trimmingCharacters(in: .whitespaces)
        guard !name.isEmpty else { return }
        createFolderWithName(name)
        newFolderName = ""
        isAddingFolder = false
    }

    @discardableResult
    func createFolderWithName(_ name: String) -> String {
        let dir = directory
        Task.detached {
            let folderURL = dir.appendingPathComponent(name, isDirectory: true)
            do {
                try FileManager.default.createDirectory(at: folderURL, withIntermediateDirectories: true)
            } catch {
                IssueLogger.log(.error, "Failed to create folder", context: folderURL.path, error: error)
            }

            let fileName = DateFormatters.dayOnly.string(from: Date()) + ".md"
            let fileURL = folderURL.appendingPathComponent(fileName)
            FileManager.default.createFile(atPath: fileURL.path, contents: nil)
        }

        loadFolders()
        selectedFolder = name
        return name
    }

    @discardableResult
    func renameFolder(_ folder: FolderItem, to newName: String) -> Bool {
        let trimmed = newName.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty, trimmed != folder.name else { return false }
        let newURL = directory.appendingPathComponent(trimmed, isDirectory: true)
        guard !FileManager.default.fileExists(atPath: newURL.path) else { return false }
        do {
            try FileManager.default.moveItem(at: folder.url, to: newURL)
            if selectedFolder == folder.name { selectedFolder = trimmed }
            loadFolders()
            return true
        } catch {
            IssueLogger.log(.error, "Failed to rename folder", context: "\(folder.name) → \(trimmed)", error: error)
            return false
        }
    }

    func deleteFolder(_ folder: FolderItem) {
        do {
            try FileManager.default.removeItem(at: folder.url)
            if selectedFolder == folder.name { selectedFolder = nil }
        } catch {
            IssueLogger.log(.error, "Failed to delete folder", context: folder.url.path, error: error)
            errorMessage = String(localized: "Unable to delete '\(folder.name)': \(error.localizedDescription)")
        }
        loadFolders()
    }

    func deleteDateEntry(_ entry: MeetingDateEntry, noteOnly: Bool = false, transcriptOnly: Bool = false) {
        do {
            if !transcriptOnly, let note = entry.noteFile {
                try FileManager.default.removeItem(at: note.url)
            }
            if !noteOnly, let transcript = entry.transcript {
                try FileManager.default.removeItem(at: transcript.url)
            }
        } catch {
            IssueLogger.log(.error, "Failed to delete date entry", error: error)
            errorMessage = String(localized: "Unable to delete: \(error.localizedDescription)")
        }
        loadFolders()
    }

    func updateCurrentFolderIcon(_ icon: String?) {
        guard let name = selectedFolder,
              let idx = folders.firstIndex(where: { $0.name == name }) else { return }
        folders[idx] = FolderItem(
            name: folders[idx].name,
            url: folders[idx].url,
            files: folders[idx].files,
            dateEntries: folders[idx].dateEntries,
            icon: icon
        )
    }

    func selectFileAtIndex(in folder: FolderItem) {
        let sorted = folder.files.sorted { $0.name.localizedStandardCompare($1.name) == .orderedDescending }
        guard !sorted.isEmpty else { return }
        let idx = min(fileIndex, sorted.count - 1)
        selectedFile = sorted[idx].url
    }

    nonisolated private static func scanFiles(in dir: URL) -> [FolderFile] {
        DirectoryScanner.scan(at: dir, fileExtension: "md").files
            .filter { $0.url.deletingPathExtension().lastPathComponent != "next" }
            .map { FolderFile(id: $0.url, name: $0.url.deletingPathExtension().lastPathComponent,
                              date: $0.date, url: $0.url) }
            .sorted { $0.name.localizedStandardCompare($1.name) == .orderedDescending }
    }

    nonisolated private static func scanDateEntries(in dir: URL, storage: FileTranscriptionStorage) -> [MeetingDateEntry] {
        MeetingDateEntry.scan(in: dir, storage: storage)
    }
}
