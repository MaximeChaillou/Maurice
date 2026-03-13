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
            guard !files.isEmpty else { return nil }
            return FolderItem(name: folder.name, url: folder.url, files: files)
        }
        .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }

    func createFolder() {
        let name = newFolderName.trimmingCharacters(in: .whitespaces)
        guard !name.isEmpty else { return }

        let folderURL = directory.appendingPathComponent(name, isDirectory: true)
        try? FileManager.default.createDirectory(at: folderURL, withIntermediateDirectories: true)

        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        let fileName = formatter.string(from: Date()) + ".md"
        let fileURL = folderURL.appendingPathComponent(fileName)
        FileManager.default.createFile(atPath: fileURL.path, contents: nil)

        newFolderName = ""
        isAddingFolder = false
        loadFolders()
        selectedFolder = name
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
}
