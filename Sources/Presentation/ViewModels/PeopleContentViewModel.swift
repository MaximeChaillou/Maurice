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
    var newCalendarEventName = ""
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
            do {
                try fm.createDirectory(at: dir, withIntermediateDirectories: true)
            } catch {
                IssueLogger.log(.warning, "Failed to create people directory", context: dir.path, error: error)
            }

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
            do {
                try FileManager.default.createDirectory(at: catURL, withIntermediateDirectories: true)
            } catch {
                IssueLogger.log(.error, "Failed to create category directory", context: catURL.path, error: error)
            }
        }
        loadFolders()
    }

    func createPerson(name: String, inCategory category: String, calendarEventName: String = "") {
        let trimmed = name.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }

        let personURL = directory
            .appendingPathComponent(category, isDirectory: true)
            .appendingPathComponent(trimmed, isDirectory: true)
        let relativePath = "\(category)/\(trimmed)"
        let trimmedEvent = calendarEventName.trimmingCharacters(in: .whitespaces)

        Task {
            await Task.detached {
                let fm = FileManager.default
                do {
                    try fm.createDirectory(at: personURL, withIntermediateDirectories: true)
                    for sub in ["1-1", "assessment", "objectifs"] {
                        try fm.createDirectory(
                            at: personURL.appendingPathComponent(sub, isDirectory: true),
                            withIntermediateDirectories: true
                        )
                    }
                } catch {
                    IssueLogger.log(.error, "Failed to create person directories", context: personURL.path, error: error)
                }
                let profileURL = personURL.appendingPathComponent("profile.md")
                if !fm.fileExists(atPath: profileURL.path) {
                    do {
                        try "# \(trimmed)\n".write(to: profileURL, atomically: true, encoding: .utf8)
                    } catch {
                        IssueLogger.log(.error, "Failed to write profile", context: profileURL.path, error: error)
                    }
                }
                let jobDescURL = personURL.appendingPathComponent("job-description.md")
                if !fm.fileExists(atPath: jobDescURL.path) {
                    fm.createFile(atPath: jobDescURL.path, contents: nil)
                }
                if !trimmedEvent.isEmpty {
                    var config = MeetingConfig()
                    config.calendarEventName = trimmedEvent
                    config.save(to: personURL.appendingPathComponent("1-1", isDirectory: true))
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
            IssueLogger.log(.error, "Failed to delete person", context: person.url.path, error: error)
            errorMessage = String(localized: "Unable to delete '\(person.name)': \(error.localizedDescription)")
        }
        loadFolders()
    }

    var categoryNames: [String] {
        categories.map(\.name)
    }
}
