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

    var hasAnyPerson: Bool {
        categories.contains { !$0.people.isEmpty }
    }

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

            var cats: [PeopleCategory] = []
            for categoryFolder in contents.folders {
                let peopleContents = DirectoryScanner.scan(at: categoryFolder.url)
                var people: [FolderItem] = peopleContents.folders.map { personFolder in
                    FolderItem(
                        name: personFolder.name,
                        url: personFolder.url,
                        files: [],
                        icon: MeetingConfigStore.shared.config(for: personFolder.url).icon,
                        relativePath: "\(categoryFolder.name)/\(personFolder.name)"
                    )
                }
                people.sort { (a: FolderItem, b: FolderItem) in
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

        if selectedPerson == nil,
           let firstPerson = categories.lazy.flatMap(\.people).first {
            selectedPerson = firstPerson.relativePath
        }
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
                    let oneOnOneURL = personURL.appendingPathComponent("1-1", isDirectory: true)
                    MeetingConfigStore.shared.update(config, for: oneOnOneURL)
                }
            }.value
            loadFolders()
            selectedPerson = relativePath
        }
    }

    func deletePerson(_ person: FolderItem) {
        do {
            try FileManager.default.removeItem(at: person.url)
            MeetingConfigStore.shared.remove(for: person.url)
            if selectedPerson == person.relativePath { selectedPerson = nil }
        } catch {
            IssueLogger.log(.error, "Failed to delete person", context: person.url.path, error: error)
            errorMessage = String(localized: "Unable to delete '\(person.name)': \(error.localizedDescription)")
        }
        loadFolders()
    }

    @discardableResult
    func renamePerson(_ person: FolderItem, to newName: String) -> Bool {
        let trimmed = newName.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty, trimmed != person.name else { return false }
        let parentURL = person.url.deletingLastPathComponent()
        let newURL = parentURL.appendingPathComponent(trimmed, isDirectory: true)
        guard !FileManager.default.fileExists(atPath: newURL.path) else { return false }
        do {
            try FileManager.default.moveItem(at: person.url, to: newURL)
            MeetingConfigStore.shared.move(from: person.url, to: newURL)
            let categoryName = parentURL.lastPathComponent
            let newRelativePath = "\(categoryName)/\(trimmed)"
            if selectedPerson == person.relativePath {
                selectedPerson = newRelativePath
            }
            loadFolders()
            return true
        } catch {
            IssueLogger.log(.error, "Failed to rename person",
                            context: "\(person.name) → \(trimmed)", error: error)
            errorMessage = String(localized: "Unable to rename '\(person.name)': \(error.localizedDescription)")
            return false
        }
    }

    func updatePersonIcon(_ person: FolderItem, icon: String?) {
        var config = MeetingConfigStore.shared.config(for: person.url)
        config.icon = icon
        MeetingConfigStore.shared.update(config, for: person.url)
        loadFolders()
    }

    var categoryNames: [String] {
        categories.map(\.name)
    }
}
