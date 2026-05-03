import XCTest
@testable import Maurice

final class FolderPathExplorerTests: XCTestCase {
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

    @discardableResult
    private func createFile(_ name: String, in dir: URL? = nil) -> URL {
        let parent = dir ?? tempDir!
        let url = parent.appendingPathComponent(name)
        FileManager.default.createFile(atPath: url.path, contents: nil)
        return url
    }

    @discardableResult
    private func createDir(_ name: String, in dir: URL? = nil) -> URL {
        let parent = dir ?? tempDir!
        let url = parent.appendingPathComponent(name, isDirectory: true)
        try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }

    // MARK: - scanContents

    func testScanContentsListsSubfoldersAlphabeticallyAscending() {
        createDir("zebra")
        createDir("alpha")
        createDir("middle")

        let contents = FolderPathExplorerView.scanContents(at: tempDir)

        XCTAssertEqual(contents.subfolderNames, ["alpha", "middle", "zebra"])
    }

    func testScanContentsListsNotesNewestFirst() {
        createFile("2026-01-01.md")
        createFile("2026-12-31.md")
        createFile("2026-06-15.md")

        let contents = FolderPathExplorerView.scanContents(at: tempDir)

        XCTAssertEqual(contents.noteBasenames, ["2026-12-31", "2026-06-15", "2026-01-01"])
    }

    func testScanContentsExcludesNextFile() {
        createFile("next.md")
        createFile("2026-04-30.md")

        let contents = FolderPathExplorerView.scanContents(at: tempDir)

        XCTAssertEqual(contents.noteBasenames, ["2026-04-30"])
    }

    func testScanContentsHidesTranscriptFromNotesAndPairsByBasename() {
        createFile("2026-04-30.md")
        createFile("2026-04-30.transcript")

        let contents = FolderPathExplorerView.scanContents(at: tempDir)

        XCTAssertEqual(contents.noteBasenames, ["2026-04-30"])
        XCTAssertEqual(contents.transcriptBasenames, ["2026-04-30"])
    }

    func testScanContentsTracksUnpairedTranscript() {
        createFile("2026-04-30.transcript")

        let contents = FolderPathExplorerView.scanContents(at: tempDir)

        XCTAssertTrue(contents.noteBasenames.isEmpty)
        XCTAssertEqual(contents.transcriptBasenames, ["2026-04-30"])
    }

    func testScanContentsIgnoresOtherFileTypes() {
        createFile("doc.pdf")
        createFile("notes.txt")
        createFile("profile.md")

        let contents = FolderPathExplorerView.scanContents(at: tempDir)

        XCTAssertEqual(contents.noteBasenames, ["profile"])
    }

    func testScanContentsReturnsEmptyForMissingDirectory() {
        let fakeDir = tempDir.appendingPathComponent("does-not-exist")

        let contents = FolderPathExplorerView.scanContents(at: fakeDir)

        XCTAssertTrue(contents.subfolderNames.isEmpty)
        XCTAssertTrue(contents.noteBasenames.isEmpty)
        XCTAssertTrue(contents.transcriptBasenames.isEmpty)
    }

    func testScanContentsCombinesFoldersAndFiles() {
        createDir("1-1")
        createDir("assessment")
        createFile("profile.md")
        createFile("job-description.md")

        let contents = FolderPathExplorerView.scanContents(at: tempDir)

        XCTAssertEqual(contents.subfolderNames, ["1-1", "assessment"])
        XCTAssertEqual(contents.noteBasenames, ["profile", "job-description"])
    }

    // MARK: - resolveDefaultSubpath

    func testResolveDefaultPicksLatestInPreferredFolder() async {
        let oneOnOne = createDir("1-1")
        createFile("2026-04-15.md", in: oneOnOne)
        createFile("2026-04-30.md", in: oneOnOne)
        createFile("profile.md")

        let resolved = await FolderPathExplorerView.resolveDefaultSubpath(
            in: tempDir, preferredFolders: ["1-1"]
        )

        XCTAssertEqual(resolved, "1-1/2026-04-30")
    }

    func testResolveDefaultFallsBackToRootWhenPreferredEmpty() async {
        createFile("profile.md")

        let resolved = await FolderPathExplorerView.resolveDefaultSubpath(
            in: tempDir, preferredFolders: ["1-1"]
        )

        XCTAssertEqual(resolved, "profile")
    }

    func testResolveDefaultReturnsEmptyWhenNothingAvailable() async {
        let resolved = await FolderPathExplorerView.resolveDefaultSubpath(
            in: tempDir, preferredFolders: ["1-1"]
        )

        XCTAssertEqual(resolved, "")
    }

    func testResolveDefaultPicksLatestRootWhenNoPreferredGiven() async {
        createFile("2026-01-01.md")
        createFile("2026-04-30.md")

        let resolved = await FolderPathExplorerView.resolveDefaultSubpath(in: tempDir)

        XCTAssertEqual(resolved, "2026-04-30")
    }

    func testResolveDefaultIgnoresNextFile() async {
        let oneOnOne = createDir("1-1")
        createFile("next.md", in: oneOnOne)
        createFile("2026-04-30.md", in: oneOnOne)

        let resolved = await FolderPathExplorerView.resolveDefaultSubpath(
            in: tempDir, preferredFolders: ["1-1"]
        )

        XCTAssertEqual(resolved, "1-1/2026-04-30")
    }

    func testResolveDefaultIgnoresTranscriptOnlyFolder() async {
        let oneOnOne = createDir("1-1")
        createFile("2026-04-30.transcript", in: oneOnOne)

        let resolved = await FolderPathExplorerView.resolveDefaultSubpath(
            in: tempDir, preferredFolders: ["1-1"]
        )

        XCTAssertEqual(resolved, "")
    }

    func testResolveDefaultTriesPreferredFoldersInOrder() async {
        // 1-1 has nothing, assessment has a file
        let assessment = createDir("assessment")
        createFile("2025-S2.md", in: assessment)

        let resolved = await FolderPathExplorerView.resolveDefaultSubpath(
            in: tempDir, preferredFolders: ["1-1", "assessment"]
        )

        XCTAssertEqual(resolved, "assessment/2025-S2")
    }

    func testResolveDefaultStopsAtFirstMatchingPreferredFolder() async {
        let oneOnOne = createDir("1-1")
        createFile("2026-04-30.md", in: oneOnOne)
        let assessment = createDir("assessment")
        createFile("2025-S2.md", in: assessment)

        let resolved = await FolderPathExplorerView.resolveDefaultSubpath(
            in: tempDir, preferredFolders: ["1-1", "assessment"]
        )

        XCTAssertEqual(resolved, "1-1/2026-04-30")
    }
}
