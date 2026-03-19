import XCTest
@testable import Maurice

final class DirectoryScannerRecursiveTests: XCTestCase {

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

    private func createFile(at relativePath: String, content: String = "test") {
        let url = tempDir.appendingPathComponent(relativePath)
        let dir = url.deletingLastPathComponent()
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        FileManager.default.createFile(atPath: url.path, contents: content.data(using: .utf8))
    }

    // MARK: - Basic recursive scan

    func testRecursiveScanFindsFilesInSubdirectories() {
        createFile(at: "top.md")
        createFile(at: "sub/nested.md")
        createFile(at: "sub/deep/deeper.md")

        let files = DirectoryScanner.scanRecursiveFiles(at: tempDir, fileExtension: "md")
        let names = Set(files.map { $0.url.lastPathComponent })

        XCTAssertEqual(files.count, 3)
        XCTAssertTrue(names.contains("top.md"))
        XCTAssertTrue(names.contains("nested.md"))
        XCTAssertTrue(names.contains("deeper.md"))
    }

    func testRecursiveScanFiltersByExtension() {
        createFile(at: "note.md")
        createFile(at: "data.txt")
        createFile(at: "sub/other.md")
        createFile(at: "sub/readme.txt")

        let files = DirectoryScanner.scanRecursiveFiles(at: tempDir, fileExtension: "md")
        let names = Set(files.map { $0.url.lastPathComponent })

        XCTAssertEqual(files.count, 2)
        XCTAssertTrue(names.contains("note.md"))
        XCTAssertTrue(names.contains("other.md"))
    }

    func testRecursiveScanEmptyDirectory() {
        let files = DirectoryScanner.scanRecursiveFiles(at: tempDir, fileExtension: "md")
        XCTAssertTrue(files.isEmpty)
    }

    func testRecursiveScanNonExistentDirectory() {
        let fakeDir = tempDir.appendingPathComponent("nope", isDirectory: true)
        let files = DirectoryScanner.scanRecursiveFiles(at: fakeDir, fileExtension: "md")
        XCTAssertTrue(files.isEmpty)
    }

    func testRecursiveScanSkipsHiddenFiles() {
        createFile(at: ".hidden.md")
        createFile(at: "visible.md")
        createFile(at: "sub/.secret.md")
        createFile(at: "sub/public.md")

        let files = DirectoryScanner.scanRecursiveFiles(at: tempDir, fileExtension: "md")
        let names = Set(files.map { $0.url.lastPathComponent })

        XCTAssertTrue(names.contains("visible.md"))
        XCTAssertTrue(names.contains("public.md"))
        XCTAssertFalse(names.contains(".hidden.md"))
        XCTAssertFalse(names.contains(".secret.md"))
    }

    func testRecursiveScanReturnsModificationDates() {
        createFile(at: "recent.md")

        let files = DirectoryScanner.scanRecursiveFiles(at: tempDir, fileExtension: "md")
        XCTAssertEqual(files.count, 1)
        XCTAssertTrue(files[0].date.timeIntervalSinceNow > -60)
    }

    func testRecursiveScanNoMatchingExtension() {
        createFile(at: "file.txt")
        createFile(at: "sub/other.json")

        let files = DirectoryScanner.scanRecursiveFiles(at: tempDir, fileExtension: "md")
        XCTAssertTrue(files.isEmpty)
    }

    // MARK: - People-like structure

    func testRecursiveScanPeopleStructure() {
        createFile(at: "Alice/profile.md")
        createFile(at: "Alice/job-description.md")
        createFile(at: "Alice/1-1/2026-03-01.md")
        createFile(at: "Alice/1-1/2026-03-15.md")
        createFile(at: "Alice/assessment/2025-S1.md")
        createFile(at: "Bob/profile.md")
        createFile(at: "Bob/objectifs/q1.md")

        let aliceFiles = DirectoryScanner.scanRecursiveFiles(
            at: tempDir.appendingPathComponent("Alice"), fileExtension: "md"
        )
        XCTAssertEqual(aliceFiles.count, 5)

        let bobFiles = DirectoryScanner.scanRecursiveFiles(
            at: tempDir.appendingPathComponent("Bob"), fileExtension: "md"
        )
        XCTAssertEqual(bobFiles.count, 2)
    }
}
