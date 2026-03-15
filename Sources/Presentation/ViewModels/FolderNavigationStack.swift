import Foundation
import Observation

@Observable
final class FolderNavigationStack {
    let rootDirectory: URL
    private(set) var directoryStack: [Folder] = []

    var currentDirectory: URL {
        directoryStack.last?.url ?? rootDirectory
    }

    var canGoBack: Bool {
        !directoryStack.isEmpty
    }

    init(rootDirectory: URL) {
        self.rootDirectory = rootDirectory
    }

    func navigateInto(_ folder: Folder) {
        directoryStack.append(folder)
    }

    func goBack() {
        guard !directoryStack.isEmpty else { return }
        directoryStack.removeLast()
    }

    func reset() {
        directoryStack.removeAll()
    }
}
