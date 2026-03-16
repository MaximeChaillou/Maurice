import Foundation
import Observation

@Observable
@MainActor
final class FolderContentViewModel {
    let directory: URL

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

    func loadFolders() {
        Task {
            await loadFoldersAsync()
        }
    }

    private func loadFoldersAsync() async {
        let dir = directory
        let result = await Task.detached {
            let fm = FileManager.default
            try? fm.createDirectory(at: dir, withIntermediateDirectories: true)

            let contents = DirectoryScanner.scan(at: dir)
            let storage = FileTranscriptionStorage()

            return contents.folders.compactMap { folder -> FolderItem? in
                let files = Self.scanFiles(in: folder.url)
                let dateEntries = Self.scanDateEntries(in: folder.url, storage: storage)
                guard !files.isEmpty || !dateEntries.isEmpty else { return nil }
                let icon = MeetingConfig.load(from: folder.url).icon
                return FolderItem(name: folder.name, url: folder.url, files: files, dateEntries: dateEntries, icon: icon)
            }
            .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
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
            try? FileManager.default.createDirectory(at: folderURL, withIntermediateDirectories: true)

            let formatter = DateFormatter()
            formatter.dateFormat = "yyyy-MM-dd"
            let fileName = formatter.string(from: Date()) + ".md"
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
            return false
        }
    }

    func deleteFolder(_ folder: FolderItem) {
        do {
            try FileManager.default.removeItem(at: folder.url)
            if selectedFolder == folder.name { selectedFolder = nil }
        } catch {
            errorMessage = "Impossible de supprimer « \(folder.name) » : \(error.localizedDescription)"
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
            errorMessage = "Impossible de supprimer : \(error.localizedDescription)"
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
            .map { FolderFile(id: $0.url, name: $0.url.deletingPathExtension().lastPathComponent,
                              date: $0.date, url: $0.url) }
            .sorted { $0.name.localizedStandardCompare($1.name) == .orderedDescending }
    }

    nonisolated private static func scanDateEntries(in dir: URL, storage: FileTranscriptionStorage) -> [MeetingDateEntry] {
        let mdFiles = DirectoryScanner.scan(at: dir, fileExtension: "md").files
        let transcriptFiles = DirectoryScanner.scan(at: dir, fileExtension: "transcript").files

        var dateMap: [String: (note: FolderFile?, transcript: StoredTranscript?)] = [:]

        for file in mdFiles {
            let datePrefix = file.url.deletingPathExtension().lastPathComponent
            let folderFile = FolderFile(
                id: file.url,
                name: datePrefix,
                date: file.date,
                url: file.url
            )
            dateMap[datePrefix, default: (nil, nil)].note = folderFile
        }

        for file in transcriptFiles {
            let datePrefix = file.url.deletingPathExtension().lastPathComponent
            if let parsed = storage.parseTranscriptFile(at: file.url) {
                dateMap[datePrefix, default: (nil, nil)].transcript = parsed
            }
        }

        let dateParser = DateFormatter()
        dateParser.dateFormat = "yyyy-MM-dd"
        dateParser.locale = Locale(identifier: "en_US_POSIX")

        return dateMap.map { key, value in
            let date = dateParser.date(from: key)
                ?? value.note?.date ?? value.transcript?.date ?? Date.distantPast
            return MeetingDateEntry(
                dateString: key,
                date: date,
                noteFile: value.note,
                transcript: value.transcript
            )
        }
        .sorted { $0.dateString.localizedStandardCompare($1.dateString) == .orderedDescending }
    }
}
