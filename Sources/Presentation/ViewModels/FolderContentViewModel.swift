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
    var skillConfig: MeetingSkillConfig = MeetingSkillConfig.load()

    var currentFolder: FolderItem? {
        guard let name = selectedFolder else { return nil }
        return folders.first { $0.name == name }
    }

    init(directory: URL) {
        self.directory = directory
    }

    func loadFolders() {
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)

        let contents = DirectoryScanner.scan(at: directory)

        folders = contents.folders.compactMap { folder in
            let files = scanFiles(in: folder.url)
            let dateEntries = scanDateEntries(in: folder.url)
            guard !files.isEmpty || !dateEntries.isEmpty else { return nil }
            return FolderItem(name: folder.name, url: folder.url, files: files, dateEntries: dateEntries)
        }
        .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
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
        let folderURL = directory.appendingPathComponent(name, isDirectory: true)
        try? FileManager.default.createDirectory(at: folderURL, withIntermediateDirectories: true)

        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        let fileName = formatter.string(from: Date()) + ".md"
        let fileURL = folderURL.appendingPathComponent(fileName)
        FileManager.default.createFile(atPath: fileURL.path, contents: nil)

        loadFolders()
        selectedFolder = name
        return name
    }

    func deleteFolder(_ folder: FolderItem) {
        try? FileManager.default.removeItem(at: folder.url)
        if selectedFolder == folder.name { selectedFolder = nil }
        loadFolders()
    }

    func deleteDateEntry(_ entry: MeetingDateEntry, noteOnly: Bool = false, transcriptOnly: Bool = false) {
        if !transcriptOnly, let note = entry.noteFile {
            try? FileManager.default.removeItem(at: note.url)
        }
        if !noteOnly, let transcript = entry.transcript {
            try? FileManager.default.removeItem(at: transcript.url)
        }
        loadFolders()
    }

    func selectFileAtIndex(in folder: FolderItem) {
        let sorted = folder.files.sorted { $0.name.localizedStandardCompare($1.name) == .orderedDescending }
        guard !sorted.isEmpty else { return }
        let idx = min(fileIndex, sorted.count - 1)
        selectedFile = sorted[idx].url
    }

    private func scanFiles(in dir: URL) -> [FolderFile] {
        DirectoryScanner.scan(at: dir, fileExtension: "md").files
            .map { FolderFile(id: $0.url, name: $0.url.deletingPathExtension().lastPathComponent,
                              date: $0.date, url: $0.url) }
            .sorted { $0.name.localizedStandardCompare($1.name) == .orderedDescending }
    }

    private func scanDateEntries(in dir: URL) -> [MeetingDateEntry] {
        let mdFiles = DirectoryScanner.scan(at: dir, fileExtension: "md").files
        let transcriptFiles = DirectoryScanner.scan(at: dir, fileExtension: "transcript").files
        let storage = FileTranscriptionStorage()

        // Group by date prefix (YYYY-MM-DD)
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

        return dateMap.map { key, value in
            let date = value.note?.date ?? value.transcript?.date ?? Date.distantPast
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
