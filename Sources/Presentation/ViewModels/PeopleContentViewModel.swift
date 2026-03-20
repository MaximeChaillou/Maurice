import Foundation
import Observation

@Observable
@MainActor
final class PeopleContentViewModel {
    private(set) var directory: URL

    private(set) var categories: [PeopleCategory] = []
    var selectedPerson: String?
    var isAddingFolder = false
    var isAddingCategory = false
    var newFolderName = ""
    var newCategoryName = ""
    var errorMessage: String?

    var currentPerson: FolderItem? {
        guard let path = selectedPerson else { return nil }
        for category in categories {
            if let person = category.people.first(where: { $0.relativePath == path }) {
                return person
            }
        }
        return nil
    }

    init(directory: URL) {
        self.directory = directory
    }

    func resetDirectory(_ newDirectory: URL) {
        directory = newDirectory
        selectedPerson = nil
        categories = []
        loadFolders()
    }

    func loadFolders() {
        Task {
            await loadFoldersAsync()
        }
    }

    private func loadFoldersAsync() async {
        let dir = directory
        let result = await Task.detached { () -> [PeopleCategory] in
            let fm = FileManager.default
            try? fm.createDirectory(at: dir, withIntermediateDirectories: true)

            let contents = DirectoryScanner.scan(at: dir)
            let storage = FileTranscriptionStorage()

            var cats: [PeopleCategory] = []
            for categoryFolder in contents.folders {
                let peopleContents = DirectoryScanner.scan(at: categoryFolder.url)
                let people = peopleContents.folders.map { personFolder in
                    let relativePath = "\(categoryFolder.name)/\(personFolder.name)"
                    let dateEntries = MeetingDateEntry.scan(in: personFolder.url, storage: storage)
                    let icon = MeetingConfig.load(from: personFolder.url).icon
                    return FolderItem(
                        name: personFolder.name,
                        url: personFolder.url,
                        files: [],
                        dateEntries: dateEntries,
                        icon: icon,
                        relativePath: relativePath
                    )
                }
                .sorted { (a: FolderItem, b: FolderItem) in
                    a.name.localizedCaseInsensitiveCompare(b.name) == .orderedAscending
                }

                cats.append(PeopleCategory(name: categoryFolder.name, people: people))
            }
            cats.sort { (a: PeopleCategory, b: PeopleCategory) in
                a.name.localizedCaseInsensitiveCompare(b.name) == .orderedAscending
            }
            return cats
        }.value

        categories = result
    }

    func createCategory(name: String) {
        let trimmed = name.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }

        let catURL = directory.appendingPathComponent(trimmed, isDirectory: true)
        Task.detached {
            try? FileManager.default.createDirectory(at: catURL, withIntermediateDirectories: true)
        }
        loadFolders()
    }

    func createPerson(name: String, inCategory category: String) {
        let trimmed = name.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }

        let personURL = directory
            .appendingPathComponent(category, isDirectory: true)
            .appendingPathComponent(trimmed, isDirectory: true)
        let relativePath = "\(category)/\(trimmed)"

        Task {
            await Task.detached {
                let fm = FileManager.default
                try? fm.createDirectory(at: personURL, withIntermediateDirectories: true)
                for sub in ["1-1", "assessment", "objectifs"] {
                    try? fm.createDirectory(
                        at: personURL.appendingPathComponent(sub, isDirectory: true),
                        withIntermediateDirectories: true
                    )
                }
                let profileURL = personURL.appendingPathComponent("profile.md")
                if !fm.fileExists(atPath: profileURL.path) {
                    try? "# \(trimmed)\n".write(to: profileURL, atomically: true, encoding: .utf8)
                }
                let jobDescURL = personURL.appendingPathComponent("job-description.md")
                if !fm.fileExists(atPath: jobDescURL.path) {
                    fm.createFile(atPath: jobDescURL.path, contents: nil)
                }
            }.value
            loadFolders()
            selectedPerson = relativePath
        }
    }

    func deletePerson(_ person: FolderItem) {
        do {
            try FileManager.default.removeItem(at: person.url)
            if selectedPerson == person.relativePath { selectedPerson = nil }
        } catch {
            errorMessage = "Impossible de supprimer \u{00AB} \(person.name) \u{00BB} : \(error.localizedDescription)"
        }
        loadFolders()
    }

    var categoryNames: [String] {
        categories.map(\.name)
    }
}
