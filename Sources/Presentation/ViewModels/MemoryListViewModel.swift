import Foundation
import Observation

@Observable
@MainActor
final class MemoryListViewModel {
    let navigation: DirectoryNavigation
    private(set) var folders: [Folder] = []
    private(set) var files: [MemoryFile] = []

    init() {
        self.navigation = DirectoryNavigation(rootDirectory: AppSettings.memoryDirectory)
    }

    func reloadDirectory() {
        navigation.reset()
        load()
    }

    func load() {
        let contents = DirectoryScanner.scan(at: navigation.currentDirectory, fileExtension: "md")

        folders = contents.folders
        files = contents.files
            .map { MemoryFile(id: $0.url, name: $0.url.deletingPathExtension().lastPathComponent,
                              folder: nil, date: $0.date, url: $0.url) }
            .sorted { $0.date > $1.date }
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
