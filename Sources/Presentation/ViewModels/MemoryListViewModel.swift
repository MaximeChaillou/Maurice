import Foundation
import Observation

@Observable
@MainActor
final class MemoryListViewModel {
    let navigation: FolderNavigationStack
    private(set) var folders: [Folder] = []
    private(set) var files: [MemoryFile] = []

    init(rootDirectory: URL = AppSettings.memoryDirectory) {
        self.navigation = FolderNavigationStack(rootDirectory: rootDirectory)
    }

    func reloadDirectory() {
        navigation.reset()
        load()
    }

    func load() {
        let dir = navigation.currentDirectory
        Task {
            let contents = await DirectoryScanner.scanAsync(at: dir, fileExtension: "md")

            folders = contents.folders.sorted {
                $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending
            }
            files = contents.files
                .map { MemoryFile(id: $0.url, name: $0.url.deletingPathExtension().lastPathComponent,
                                  folder: nil, date: $0.date, url: $0.url) }
                .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
        }
    }

    func navigateInto(_ folder: Folder) {
        navigation.navigateInto(folder)
        load()
    }

    func goBack() {
        navigation.goBack()
        load()
    }
}
