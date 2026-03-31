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

        viewModel = PeopleContentViewModel(directory: peopleDir)
    }

    override func tearDown() async throws {
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

    // MARK: - Helpers

    private func loadAndWait() async {
        viewModel.loadFolders()
        try? await Task.sleep(for: .milliseconds(100))
    }
}
