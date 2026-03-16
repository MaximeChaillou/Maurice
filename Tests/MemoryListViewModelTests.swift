import XCTest
@testable import Maurice

@MainActor
final class MemoryListViewModelTests: XCTestCase {

    private var tempDir: URL!

    override func setUp() async throws {
        try await super.setUp()
        await MainActor.run {
            tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
            try? FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        }
    }

    override func tearDown() async throws {
        await MainActor.run {
            try? FileManager.default.removeItem(at: tempDir)
        }
        try await super.tearDown()
    }

    private func createFile(_ name: String, in dir: URL? = nil) {
        let target = dir ?? tempDir!
        let url = target.appendingPathComponent(name)
        FileManager.default.createFile(atPath: url.path, contents: "# Test".data(using: .utf8))
    }

    private func createSubfolder(_ name: String) -> URL {
        let url = tempDir.appendingPathComponent(name, isDirectory: true)
        try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }

    // MARK: - Initial state

    func testInitialState() {
        let vm = MemoryListViewModel(rootDirectory: tempDir)
        XCTAssertTrue(vm.folders.isEmpty)
        XCTAssertTrue(vm.files.isEmpty)
        XCTAssertFalse(vm.navigation.canGoBack)
    }

    // MARK: - load

    func testLoadFindsMarkdownFiles() async throws {
        createFile("note1.md")
        createFile("note2.md")

        let vm = MemoryListViewModel(rootDirectory: tempDir)
        vm.load()
        try await Task.sleep(for: .milliseconds(300))

        XCTAssertEqual(vm.files.count, 2)
        let names = vm.files.map(\.name)
        XCTAssertTrue(names.contains("note1"))
        XCTAssertTrue(names.contains("note2"))
    }

    func testLoadFindsFolders() async throws {
        _ = createSubfolder("SubFolder")

        let vm = MemoryListViewModel(rootDirectory: tempDir)
        vm.load()
        try await Task.sleep(for: .milliseconds(300))

        XCTAssertEqual(vm.folders.count, 1)
        XCTAssertEqual(vm.folders.first?.name, "SubFolder")
    }

    func testLoadIgnoresNonMarkdownFiles() async throws {
        createFile("notes.md")
        createFile("image.png")

        let vm = MemoryListViewModel(rootDirectory: tempDir)
        vm.load()
        try await Task.sleep(for: .milliseconds(300))

        XCTAssertEqual(vm.files.count, 1)
        XCTAssertEqual(vm.files.first?.name, "notes")
    }

    func testLoadSortsByDateDescending() async throws {
        // Create files with different dates by writing sequentially
        createFile("old.md")
        try await Task.sleep(for: .milliseconds(50))
        createFile("new.md")

        let vm = MemoryListViewModel(rootDirectory: tempDir)
        vm.load()
        try await Task.sleep(for: .milliseconds(300))

        XCTAssertEqual(vm.files.count, 2)
        // Newest first
        XCTAssertEqual(vm.files.first?.name, "new")
    }

    // MARK: - navigateInto / goBack

    func testNavigateIntoFolder() async throws {
        let sub = createSubfolder("Deep")
        createFile("inside.md", in: sub)

        let vm = MemoryListViewModel(rootDirectory: tempDir)
        vm.load()
        try await Task.sleep(for: .milliseconds(300))

        let folder = vm.folders.first!
        vm.navigateInto(folder)
        try await Task.sleep(for: .milliseconds(300))

        XCTAssertTrue(vm.navigation.canGoBack)
        XCTAssertEqual(vm.files.count, 1)
        XCTAssertEqual(vm.files.first?.name, "inside")
    }

    func testGoBackReturnsToRoot() async throws {
        let sub = createSubfolder("Deep")
        createFile("root.md")
        createFile("inside.md", in: sub)

        let vm = MemoryListViewModel(rootDirectory: tempDir)
        vm.load()
        try await Task.sleep(for: .milliseconds(300))

        let folder = vm.folders.first!
        vm.navigateInto(folder)
        try await Task.sleep(for: .milliseconds(300))
        XCTAssertEqual(vm.files.first?.name, "inside")

        vm.goBack()
        try await Task.sleep(for: .milliseconds(300))

        XCTAssertFalse(vm.navigation.canGoBack)
        XCTAssertEqual(vm.files.first?.name, "root")
    }

    // MARK: - reloadDirectory

    func testReloadDirectoryResetsNavigation() async throws {
        let sub = createSubfolder("Sub")
        createFile("file.md", in: sub)

        let vm = MemoryListViewModel(rootDirectory: tempDir)
        vm.load()
        try await Task.sleep(for: .milliseconds(300))

        vm.navigateInto(vm.folders.first!)
        try await Task.sleep(for: .milliseconds(300))
        XCTAssertTrue(vm.navigation.canGoBack)

        vm.reloadDirectory()
        try await Task.sleep(for: .milliseconds(300))

        XCTAssertFalse(vm.navigation.canGoBack)
    }

    func testLoadEmptyDirectory() async throws {
        let vm = MemoryListViewModel(rootDirectory: tempDir)
        vm.load()
        try await Task.sleep(for: .milliseconds(300))

        XCTAssertTrue(vm.files.isEmpty)
        XCTAssertTrue(vm.folders.isEmpty)
    }
}
