import XCTest
@testable import Maurice

@MainActor
final class PeopleContentViewModelTests: XCTestCase {

    private var tempDir: URL!
    private var viewModel: PeopleContentViewModel!
    private var originalRootDirectory: String?

    override func setUp() async throws {
        try await super.setUp()
        tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        let peopleDir = tempDir.appendingPathComponent("People", isDirectory: true)
        try FileManager.default.createDirectory(at: peopleDir, withIntermediateDirectories: true)

        originalRootDirectory = UserDefaults.standard.string(forKey: "rootDirectory")
        UserDefaults.standard.set(tempDir.path, forKey: "rootDirectory")
        MeetingConfigStore.shared.reset()

        viewModel = PeopleContentViewModel(directory: peopleDir)
    }

    override func tearDown() async throws {
        MeetingConfigStore.shared.reset()
        if let original = originalRootDirectory {
            UserDefaults.standard.set(original, forKey: "rootDirectory")
        } else {
            UserDefaults.standard.removeObject(forKey: "rootDirectory")
        }
        try? FileManager.default.removeItem(at: tempDir)
        try await super.tearDown()
    }

    // MARK: - Loading categories

    func testLoadEmptyDirectory() async throws {
        await loadAndWait()
        XCTAssertTrue(viewModel.categories.isEmpty)
    }

    func testLoadCategoriesWithPeople() async throws {
        let fm = FileManager.default
        let teamDir = tempDir.appendingPathComponent("People/Team", isDirectory: true)
        let aliceDir = teamDir.appendingPathComponent("Alice", isDirectory: true)
        try fm.createDirectory(at: aliceDir, withIntermediateDirectories: true)

        await loadAndWait()

        XCTAssertEqual(viewModel.categories.count, 1)
        XCTAssertEqual(viewModel.categories.first?.name, "Team")
        XCTAssertEqual(viewModel.categories.first?.people.count, 1)
        XCTAssertEqual(viewModel.categories.first?.people.first?.name, "Alice")
        XCTAssertEqual(viewModel.categories.first?.people.first?.relativePath, "Team/Alice")
    }

    func testCategoriesSortedAlphabetically() async throws {
        let fm = FileManager.default
        let peopleDir = tempDir.appendingPathComponent("People", isDirectory: true)
        try fm.createDirectory(
            at: peopleDir.appendingPathComponent("Managers/Bob", isDirectory: true),
            withIntermediateDirectories: true
        )
        try fm.createDirectory(
            at: peopleDir.appendingPathComponent("Equipe/Alice", isDirectory: true),
            withIntermediateDirectories: true
        )

        await loadAndWait()

        XCTAssertEqual(viewModel.categories.count, 2)
        XCTAssertEqual(viewModel.categories[0].name, "Equipe")
        XCTAssertEqual(viewModel.categories[1].name, "Managers")
    }

    // MARK: - Selection

    func testCurrentPersonReturnsCorrectItem() async throws {
        let fm = FileManager.default
        let aliceDir = tempDir.appendingPathComponent("People/Team/Alice", isDirectory: true)
        try fm.createDirectory(at: aliceDir, withIntermediateDirectories: true)

        await loadAndWait()
        viewModel.selectedPerson = "Team/Alice"

        XCTAssertNotNil(viewModel.currentPerson)
        XCTAssertEqual(viewModel.currentPerson?.name, "Alice")
        XCTAssertEqual(viewModel.currentPerson?.relativePath, "Team/Alice")
    }

    func testCurrentPersonNilWhenNoSelection() async throws {
        XCTAssertNil(viewModel.selectedPerson)
        XCTAssertNil(viewModel.currentPerson)
    }

    // MARK: - Creation

    func testCreateCategory() async throws {
        viewModel.createCategory(name: "Managers")

        // Wait for file system operation
        try await Task.sleep(for: .milliseconds(100))
        await loadAndWait()

        XCTAssertEqual(viewModel.categories.count, 1)
        XCTAssertEqual(viewModel.categories.first?.name, "Managers")
    }

    func testCreatePerson() async throws {
        let fm = FileManager.default
        let teamDir = tempDir.appendingPathComponent("People/Team", isDirectory: true)
        try fm.createDirectory(at: teamDir, withIntermediateDirectories: true)

        await loadAndWait()

        viewModel.createPerson(name: "Alice", inCategory: "Team")
        try await Task.sleep(for: .milliseconds(200))
        await loadAndWait()

        XCTAssertEqual(viewModel.selectedPerson, "Team/Alice")

        let aliceDir = teamDir.appendingPathComponent("Alice", isDirectory: true)
        XCTAssertTrue(fm.fileExists(atPath: aliceDir.path))
        XCTAssertTrue(fm.fileExists(atPath: aliceDir.appendingPathComponent("1-1").path))
        XCTAssertTrue(fm.fileExists(atPath: aliceDir.appendingPathComponent("profile.md").path))
    }

    func testCreatePersonWithCalendarEventNameSavesConfig() async throws {
        let fm = FileManager.default
        let teamDir = tempDir.appendingPathComponent("People/Team", isDirectory: true)
        try fm.createDirectory(at: teamDir, withIntermediateDirectories: true)

        await loadAndWait()

        viewModel.createPerson(
            name: "Alice",
            inCategory: "Team",
            calendarEventName: "1-1 Alice / Maxime"
        )
        try await Task.sleep(for: .milliseconds(200))

        let oneOnOneDir = teamDir
            .appendingPathComponent("Alice", isDirectory: true)
            .appendingPathComponent("1-1", isDirectory: true)
        let config = MeetingConfigStore.shared.config(for: oneOnOneDir)
        XCTAssertEqual(config.calendarEventName, "1-1 Alice / Maxime")
    }

    func testCreatePersonWithoutCalendarEventNameSkipsConfig() async throws {
        let fm = FileManager.default
        let teamDir = tempDir.appendingPathComponent("People/Team", isDirectory: true)
        try fm.createDirectory(at: teamDir, withIntermediateDirectories: true)

        await loadAndWait()

        viewModel.createPerson(name: "Alice", inCategory: "Team", calendarEventName: "")
        try await Task.sleep(for: .milliseconds(200))

        let oneOnOneDir = teamDir
            .appendingPathComponent("Alice", isDirectory: true)
            .appendingPathComponent("1-1", isDirectory: true)
        XCTAssertNil(MeetingConfigStore.shared.config(for: oneOnOneDir).calendarEventName)
    }

    func testCreatePersonTrimsCalendarEventName() async throws {
        let fm = FileManager.default
        let teamDir = tempDir.appendingPathComponent("People/Team", isDirectory: true)
        try fm.createDirectory(at: teamDir, withIntermediateDirectories: true)

        await loadAndWait()

        viewModel.createPerson(
            name: "Alice",
            inCategory: "Team",
            calendarEventName: "   1-1 Alice   "
        )
        try await Task.sleep(for: .milliseconds(200))

        let oneOnOneDir = teamDir
            .appendingPathComponent("Alice", isDirectory: true)
            .appendingPathComponent("1-1", isDirectory: true)
        let config = MeetingConfigStore.shared.config(for: oneOnOneDir)
        XCTAssertEqual(config.calendarEventName, "1-1 Alice")
    }

    func testCreatePersonWithWhitespaceOnlyEventNameSkipsConfig() async throws {
        let fm = FileManager.default
        let teamDir = tempDir.appendingPathComponent("People/Team", isDirectory: true)
        try fm.createDirectory(at: teamDir, withIntermediateDirectories: true)

        await loadAndWait()

        viewModel.createPerson(
            name: "Alice",
            inCategory: "Team",
            calendarEventName: "   "
        )
        try await Task.sleep(for: .milliseconds(200))

        let oneOnOneDir = teamDir
            .appendingPathComponent("Alice", isDirectory: true)
            .appendingPathComponent("1-1", isDirectory: true)
        XCTAssertNil(MeetingConfigStore.shared.config(for: oneOnOneDir).calendarEventName)
    }

    // MARK: - Deletion

    func testDeletePerson() async throws {
        let fm = FileManager.default
        let aliceDir = tempDir.appendingPathComponent("People/Team/Alice", isDirectory: true)
        try fm.createDirectory(at: aliceDir, withIntermediateDirectories: true)

        await loadAndWait()
        viewModel.selectedPerson = "Team/Alice"

        let person = viewModel.currentPerson!
        viewModel.deletePerson(person)

        XCTAssertNil(viewModel.selectedPerson)
        XCTAssertFalse(fm.fileExists(atPath: aliceDir.path))
    }

    // MARK: - Category names

    func testCategoryNamesReturnsNames() async throws {
        let fm = FileManager.default
        let peopleDir = tempDir.appendingPathComponent("People", isDirectory: true)
        try fm.createDirectory(
            at: peopleDir.appendingPathComponent("Team", isDirectory: true),
            withIntermediateDirectories: true
        )
        try fm.createDirectory(
            at: peopleDir.appendingPathComponent("Managers", isDirectory: true),
            withIntermediateDirectories: true
        )

        await loadAndWait()

        XCTAssertEqual(viewModel.categoryNames.count, 2)
        XCTAssertTrue(viewModel.categoryNames.contains("Team"))
        XCTAssertTrue(viewModel.categoryNames.contains("Managers"))
    }

    func testCategoryNamesEmptyWhenNoCategories() async throws {
        await loadAndWait()
        XCTAssertTrue(viewModel.categoryNames.isEmpty)
    }

    func testCreateCategoryThenCategoryNamesUpdated() async throws {
        viewModel.createCategory(name: "Engineering")

        try await Task.sleep(for: .milliseconds(100))
        await loadAndWait()

        XCTAssertEqual(viewModel.categoryNames, ["Engineering"])
    }

    func testCreateCategoryIgnoresEmptyName() async throws {
        viewModel.createCategory(name: "   ")

        try await Task.sleep(for: .milliseconds(100))
        await loadAndWait()

        XCTAssertTrue(viewModel.categories.isEmpty)
    }

    // MARK: - hasAnyPerson

    func testHasAnyPersonFalseWhenNoCategories() async throws {
        await loadAndWait()
        XCTAssertFalse(viewModel.hasAnyPerson)
    }

    func testHasAnyPersonFalseWhenCategoriesButNoPeople() async throws {
        let fm = FileManager.default
        let teamDir = tempDir.appendingPathComponent("People/Team", isDirectory: true)
        try fm.createDirectory(at: teamDir, withIntermediateDirectories: true)

        await loadAndWait()

        XCTAssertEqual(viewModel.categories.count, 1)
        XCTAssertFalse(viewModel.hasAnyPerson,
                       "Empty category with no people must not count as hasAnyPerson")
    }

    func testHasAnyPersonTrueWhenAtLeastOnePersonExists() async throws {
        let fm = FileManager.default
        let aliceDir = tempDir.appendingPathComponent("People/Team/Alice", isDirectory: true)
        try fm.createDirectory(at: aliceDir, withIntermediateDirectories: true)

        await loadAndWait()

        XCTAssertTrue(viewModel.hasAnyPerson)
    }

    // MARK: - Auto-select first person

    func testLoadFoldersAutoSelectsFirstPersonWhenNoSelection() async throws {
        let fm = FileManager.default
        let aliceDir = tempDir.appendingPathComponent("People/Team/Alice", isDirectory: true)
        try fm.createDirectory(at: aliceDir, withIntermediateDirectories: true)

        XCTAssertNil(viewModel.selectedPerson)
        await loadAndWait()

        XCTAssertEqual(viewModel.selectedPerson, "Team/Alice",
                       "First person should be auto-selected when none was selected")
    }

    func testLoadFoldersDoesNotOverrideExistingSelection() async throws {
        let fm = FileManager.default
        let aliceDir = tempDir.appendingPathComponent("People/Team/Alice", isDirectory: true)
        let bobDir = tempDir.appendingPathComponent("People/Team/Bob", isDirectory: true)
        try fm.createDirectory(at: aliceDir, withIntermediateDirectories: true)
        try fm.createDirectory(at: bobDir, withIntermediateDirectories: true)

        viewModel.selectedPerson = "Team/Bob"
        await loadAndWait()

        XCTAssertEqual(viewModel.selectedPerson, "Team/Bob",
                       "Existing selection must not be overridden by auto-select")
    }

    func testLoadFoldersWithEmptyDirectoryLeavesSelectionNil() async throws {
        XCTAssertNil(viewModel.selectedPerson)
        await loadAndWait()
        XCTAssertNil(viewModel.selectedPerson)
    }

    // MARK: - renamePerson

    func testRenamePersonSuccess() async throws {
        let fm = FileManager.default
        let aliceDir = tempDir.appendingPathComponent("People/Team/Alice", isDirectory: true)
        try fm.createDirectory(at: aliceDir, withIntermediateDirectories: true)

        await loadAndWait()
        viewModel.selectedPerson = "Team/Alice"
        let person = viewModel.currentPerson!

        let result = viewModel.renamePerson(person, to: "Alicia")

        XCTAssertTrue(result)
        XCTAssertFalse(fm.fileExists(atPath: aliceDir.path))
        let renamedDir = tempDir.appendingPathComponent("People/Team/Alicia", isDirectory: true)
        XCTAssertTrue(fm.fileExists(atPath: renamedDir.path))
        XCTAssertEqual(viewModel.selectedPerson, "Team/Alicia",
                       "Selection should follow the renamed person")
    }

    func testRenamePersonWithEmptyNameReturnsFalse() async throws {
        let fm = FileManager.default
        let aliceDir = tempDir.appendingPathComponent("People/Team/Alice", isDirectory: true)
        try fm.createDirectory(at: aliceDir, withIntermediateDirectories: true)

        await loadAndWait()
        let person = viewModel.categories.first!.people.first!

        XCTAssertFalse(viewModel.renamePerson(person, to: "   "))
        XCTAssertTrue(fm.fileExists(atPath: aliceDir.path))
    }

    func testRenamePersonWithSameNameReturnsFalse() async throws {
        let fm = FileManager.default
        let aliceDir = tempDir.appendingPathComponent("People/Team/Alice", isDirectory: true)
        try fm.createDirectory(at: aliceDir, withIntermediateDirectories: true)

        await loadAndWait()
        let person = viewModel.categories.first!.people.first!

        XCTAssertFalse(viewModel.renamePerson(person, to: "Alice"))
    }

    func testRenamePersonToExistingNameReturnsFalse() async throws {
        let fm = FileManager.default
        let aliceDir = tempDir.appendingPathComponent("People/Team/Alice", isDirectory: true)
        let bobDir = tempDir.appendingPathComponent("People/Team/Bob", isDirectory: true)
        try fm.createDirectory(at: aliceDir, withIntermediateDirectories: true)
        try fm.createDirectory(at: bobDir, withIntermediateDirectories: true)

        await loadAndWait()
        let alice = viewModel.categories.first!.people.first { $0.name == "Alice" }!

        XCTAssertFalse(viewModel.renamePerson(alice, to: "Bob"))
        XCTAssertTrue(fm.fileExists(atPath: aliceDir.path),
                      "Original folder must be preserved when target already exists")
    }

    func testRenamePersonRekeysMeetingConfig() async throws {
        let fm = FileManager.default
        let aliceDir = tempDir.appendingPathComponent("People/Team/Alice", isDirectory: true)
        let oneOnOneDir = aliceDir.appendingPathComponent("1-1", isDirectory: true)
        try fm.createDirectory(at: oneOnOneDir, withIntermediateDirectories: true)

        MeetingConfigStore.shared.update(
            MeetingConfig(calendarEventName: "1-1 Alice", actions: []),
            for: oneOnOneDir
        )

        // Pre-condition: the config is in the store under the Alice key.
        XCTAssertEqual(
            MeetingConfigStore.shared.config(for: oneOnOneDir).calendarEventName,
            "1-1 Alice",
            "Test pre-condition: config must be stored before rename"
        )

        // Build the FolderItem directly with the URL we know the rename will use,
        // so the test isn't coupled to DirectoryScanner's URL form.
        let person = FolderItem(
            name: "Alice",
            url: aliceDir,
            files: [],
            relativePath: "Team/Alice"
        )
        viewModel.selectedPerson = "Team/Alice"

        XCTAssertTrue(viewModel.renamePerson(person, to: "Alicia"))

        let newOneOnOne = tempDir.appendingPathComponent("People/Team/Alicia/1-1", isDirectory: true)
        XCTAssertEqual(
            MeetingConfigStore.shared.config(for: newOneOnOne).calendarEventName,
            "1-1 Alice",
            "Config must be re-keyed under the renamed person"
        )
        XCTAssertNil(
            MeetingConfigStore.shared.config(for: oneOnOneDir).calendarEventName,
            "Config under the old key must no longer be found"
        )
    }

    func testRenamePersonKeepsSelectionWhenDifferentPersonRenamed() async throws {
        let fm = FileManager.default
        let aliceDir = tempDir.appendingPathComponent("People/Team/Alice", isDirectory: true)
        let bobDir = tempDir.appendingPathComponent("People/Team/Bob", isDirectory: true)
        try fm.createDirectory(at: aliceDir, withIntermediateDirectories: true)
        try fm.createDirectory(at: bobDir, withIntermediateDirectories: true)

        await loadAndWait()
        viewModel.selectedPerson = "Team/Alice"
        let bob = viewModel.categories.first!.people.first { $0.name == "Bob" }!

        XCTAssertTrue(viewModel.renamePerson(bob, to: "Bobby"))

        XCTAssertEqual(viewModel.selectedPerson, "Team/Alice",
                       "Renaming a different person must not change selection")
    }

    // MARK: - updatePersonIcon

    func testUpdatePersonIconStoresIconInConfig() async throws {
        let fm = FileManager.default
        let aliceDir = tempDir.appendingPathComponent("People/Team/Alice", isDirectory: true)
        try fm.createDirectory(at: aliceDir, withIntermediateDirectories: true)

        await loadAndWait()
        let person = viewModel.categories.first!.people.first!

        viewModel.updatePersonIcon(person, icon: "👩‍💻")
        try await Task.sleep(for: .milliseconds(150))

        XCTAssertEqual(MeetingConfigStore.shared.config(for: aliceDir).icon, "👩‍💻")
    }

    func testUpdatePersonIconClearsIconWhenNil() async throws {
        let fm = FileManager.default
        let aliceDir = tempDir.appendingPathComponent("People/Team/Alice", isDirectory: true)
        try fm.createDirectory(at: aliceDir, withIntermediateDirectories: true)

        MeetingConfigStore.shared.update(
            MeetingConfig(icon: "👩‍💻", actions: []),
            for: aliceDir
        )
        try await Task.sleep(for: .milliseconds(150))

        await loadAndWait()
        let person = viewModel.categories.first!.people.first!

        viewModel.updatePersonIcon(person, icon: nil)
        try await Task.sleep(for: .milliseconds(150))

        XCTAssertNil(MeetingConfigStore.shared.config(for: aliceDir).icon)
    }

    func testUpdatePersonIconPreservesOtherConfigFields() async throws {
        let fm = FileManager.default
        let aliceDir = tempDir.appendingPathComponent("People/Team/Alice", isDirectory: true)
        try fm.createDirectory(at: aliceDir, withIntermediateDirectories: true)

        MeetingConfigStore.shared.update(
            MeetingConfig(calendarEventName: "1-1 Alice", actions: []),
            for: aliceDir
        )
        try await Task.sleep(for: .milliseconds(150))

        await loadAndWait()
        let person = viewModel.categories.first!.people.first!

        viewModel.updatePersonIcon(person, icon: "🌟")
        try await Task.sleep(for: .milliseconds(150))

        let config = MeetingConfigStore.shared.config(for: aliceDir)
        XCTAssertEqual(config.icon, "🌟")
        XCTAssertEqual(config.calendarEventName, "1-1 Alice",
                       "Updating icon must not wipe calendarEventName")
    }

    // MARK: - Helpers

    private func loadAndWait() async {
        viewModel.loadFolders()
        try? await Task.sleep(for: .milliseconds(100))
    }
}
