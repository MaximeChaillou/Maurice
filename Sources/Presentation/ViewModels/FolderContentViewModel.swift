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
        let result = await Task.detached { () -> [FolderItem] in
            let fm = FileManager.default
            do {
                try fm.createDirectory(at: dir, withIntermediateDirectories: true)
            } catch {
                IssueLogger.log(.warning, "Failed to create directory", context: dir.path, error: error)
            }

            let contents = DirectoryScanner.scan(at: dir)

            var items: [FolderItem] = []
            for folder in contents.folders {
                let files = Self.scanFiles(in: folder.url)
                let dateEntries = await Self.scanDateEntries(in: folder.url)
                let icon = MeetingConfig.load(from: folder.url).icon
                items.append(FolderItem(
                    name: folder.name, url: folder.url, files: files,
                    dateEntries: dateEntries, icon: icon
                ))
            }
            items.sort { (a: FolderItem, b: FolderItem) in
                a.name.localizedCaseInsensitiveCompare(b.name) == .orderedAscending
            }
            return items
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
            if !noteOnly, let transcriptFile = entry.transcriptFile {
                try FileManager.default.removeItem(at: transcriptFile.url)
            }
        } catch {
            IssueLogger.log(.error, "Failed to delete date entry", error: error)
            errorMessage = String(localized: "Unable to delete: \(error.localizedDescription)")
        }
        loadFolders()
    }

    func loadMeetingConfig(for folderName: String, from url: URL) async {
        let config = await Task.detached {
            MeetingConfig.load(from: url)
        }.value
        guard selectedFolder == folderName else { return }
        meetingConfig = config
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

    func moveFolderContent(_ folder: FolderItem, to destination: URL) {
        let sourceURL = folder.url
        Task {
            let error: String? = await Task.detached {
                let fm = FileManager.default
                do {
                    try fm.createDirectory(at: destination, withIntermediateDirectories: true)
                } catch {
                    return "Failed to create destination: \(error.localizedDescription)"
                }

                let contents = DirectoryScanner.scan(at: sourceURL)
                for file in contents.files {
                    let ext = file.url.pathExtension
                    guard ext == "md" || ext == "transcript" else { continue }
                    let name = file.url.lastPathComponent
                    guard name != "next.md" else { continue }
                    let destFile = destination.appendingPathComponent(name)
                    do {
                        if fm.fileExists(atPath: destFile.path) {
                            try Self.mergeFile(from: file.url, to: destFile)
                        } else {
                            try fm.moveItem(at: file.url, to: destFile)
                        }
                    } catch {
                        IssueLogger.log(.error, "Failed to move file", context: name, error: error)
                        return "Failed to move '\(name)': \(error.localizedDescription)"
                    }
                }
                return nil
            }.value

            if let error {
                errorMessage = error
            } else {
                if selectedFolder == folder.name { selectedFolder = nil }
            }
            loadFolders()
        }
    }

    nonisolated static func listMoveDestinations(excluding folder: FolderItem) -> [MoveDestination] {
        var destinations: [MoveDestination] = []

        // Other meetings
        let meetingsDir = AppSettings.meetingsDirectory
        let meetingFolders = DirectoryScanner.scan(at: meetingsDir).folders
        for meeting in meetingFolders where meeting.name != folder.name {
            destinations.append(MoveDestination(
                name: meeting.name,
                url: meeting.url,
                section: "Meetings"
            ))
        }

        // People 1-1 subfolders
        let peopleDir = AppSettings.peopleDirectory
        let categories = DirectoryScanner.scan(at: peopleDir).folders
        for category in categories {
            let people = DirectoryScanner.scan(at: category.url).folders
            for person in people {
                let oneOnOneDir = person.url.appendingPathComponent("1-1", isDirectory: true)
                if FileManager.default.fileExists(atPath: oneOnOneDir.path) {
                    destinations.append(MoveDestination(
                        name: "\(person.name) (1-1)",
                        url: oneOnOneDir,
                        section: category.name
                    ))
                }
            }
        }

        return destinations
    }

    nonisolated private static func mergeFile(from source: URL, to dest: URL) throws {
        let sourceContent = try String(contentsOf: source, encoding: .utf8)
        let destContent = try String(contentsOf: dest, encoding: .utf8)
        let merged = destContent.trimmingCharacters(in: .whitespacesAndNewlines)
            + "\n\n" + sourceContent.trimmingCharacters(in: .whitespacesAndNewlines) + "\n"
        try merged.write(to: dest, atomically: true, encoding: .utf8)
        try FileManager.default.removeItem(at: source)
    }

    nonisolated private static func scanFiles(in dir: URL) -> [FolderFile] {
        DirectoryScanner.scan(at: dir, fileExtension: "md").files
            .filter { $0.url.deletingPathExtension().lastPathComponent != "next" }
            .map { FolderFile(id: $0.url, name: $0.url.deletingPathExtension().lastPathComponent,
                              date: $0.date, url: $0.url) }
            .sorted { $0.name.localizedStandardCompare($1.name) == .orderedDescending }
    }

    nonisolated private static func scanDateEntries(in dir: URL) async -> [MeetingDateEntry] {
        await MeetingDateEntry.scan(in: dir)
    }
}
