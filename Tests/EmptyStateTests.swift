import XCTest
@testable import Maurice

@MainActor
final class EmptyStateTests: XCTestCase {

    private var tempDir: URL!

    override func setUp() async throws {
        try await super.setUp()
        tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
    }

    override func tearDown() async throws {
        try? FileManager.default.removeItem(at: tempDir)
        try await super.tearDown()
    }

    // MARK: - FolderContentViewModel empty state

    func testFolderContentViewModelEmptyFolders() {
        let vm = FolderContentViewModel(directory: tempDir)
        vm.loadFolders()
        XCTAssertTrue(vm.folders.isEmpty)
        XCTAssertNil(vm.currentFolder)
    }

    func testFolderContentViewModelNonEmpty() async throws {
        let sub = tempDir.appendingPathComponent("Standup", isDirectory: true)
        try FileManager.default.createDirectory(at: sub, withIntermediateDirectories: true)

        let vm = FolderContentViewModel(directory: tempDir)
        vm.loadFolders()
        try await Task.sleep(for: .milliseconds(500))

        XCTAssertFalse(vm.folders.isEmpty)
    }

    // MARK: - PeopleContentViewModel empty state

    func testPeopleViewModelEmptyCategories() async throws {
        let peopleDir = tempDir.appendingPathComponent("People", isDirectory: true)
        try FileManager.default.createDirectory(at: peopleDir, withIntermediateDirectories: true)

        let originalRoot = UserDefaults.standard.string(forKey: "rootDirectory")
        UserDefaults.standard.set(tempDir.path, forKey: "rootDirectory")
        defer {
            if let original = originalRoot {
                UserDefaults.standard.set(original, forKey: "rootDirectory")
            } else {
                UserDefaults.standard.removeObject(forKey: "rootDirectory")
            }
        }

        let vm = PeopleContentViewModel(directory: peopleDir)
        vm.loadFolders()
        try await Task.sleep(for: .milliseconds(200))

        XCTAssertTrue(vm.categories.isEmpty)
        XCTAssertNil(vm.currentPerson)
    }

    func testPeopleViewModelNonEmptyCategories() async throws {
        let fm = FileManager.default
        let peopleDir = tempDir.appendingPathComponent("People", isDirectory: true)
        let teamDir = peopleDir.appendingPathComponent("Team/Alice", isDirectory: true)
        try fm.createDirectory(at: teamDir, withIntermediateDirectories: true)

        let originalRoot = UserDefaults.standard.string(forKey: "rootDirectory")
        UserDefaults.standard.set(tempDir.path, forKey: "rootDirectory")
        defer {
            if let original = originalRoot {
                UserDefaults.standard.set(original, forKey: "rootDirectory")
            } else {
                UserDefaults.standard.removeObject(forKey: "rootDirectory")
            }
        }

        let vm = PeopleContentViewModel(directory: peopleDir)
        vm.loadFolders()
        try await Task.sleep(for: .milliseconds(200))

        XCTAssertFalse(vm.categories.isEmpty)
    }
}
