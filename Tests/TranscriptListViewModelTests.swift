import XCTest
@testable import Maurice

final class MockTranscriptionStorage: TranscriptionStorage, @unchecked Sendable {
    var directoryContents = TranscriptDirectoryContents(folders: [], transcripts: [])
    var shouldThrowOnList = false
    var shouldThrowOnDelete = false
    var shouldThrowOnRename = false
    var deletedTranscripts: [StoredTranscript] = []
    var renamedPairs: [(StoredTranscript, String)] = []

    func save(_ transcription: Transcription) async throws {}

    func beginLiveSession(startDate: Date, subdirectory: String?) throws -> URL {
        URL(fileURLWithPath: "/tmp/live.transcript")
    }

    func appendEntry(_ entry: TranscriptionEntry, to fileURL: URL) throws {}

    func list() async throws -> [StoredTranscript] { [] }

    func listDirectory(_ url: URL) async throws -> TranscriptDirectoryContents {
        if shouldThrowOnList { throw TestError.mock }
        return directoryContents
    }

    func delete(_ transcript: StoredTranscript) async throws {
        if shouldThrowOnDelete { throw TestError.mock }
        deletedTranscripts.append(transcript)
    }

    func rename(_ transcript: StoredTranscript, to newName: String) async throws -> StoredTranscript {
        if shouldThrowOnRename { throw TestError.mock }
        renamedPairs.append((transcript, newName))
        return StoredTranscript(id: transcript.id, name: newName, date: transcript.date, entries: transcript.entries)
    }
}

private enum TestError: LocalizedError {
    case mock
    var errorDescription: String? { "mock error" }
}

@MainActor
final class TranscriptListViewModelTests: XCTestCase {

    private func makeTranscript(name: String = "Test") -> StoredTranscript {
        StoredTranscript(
            id: URL(fileURLWithPath: "/tmp/\(name).transcript"),
            name: name,
            date: Date(),
            entries: [.text("Hello")]
        )
    }

    // MARK: - load

    func testLoadPopulatesFoldersAndTranscripts() async throws {
        let storage = MockTranscriptionStorage()
        let transcript = makeTranscript()
        let folder = Folder(url: URL(fileURLWithPath: "/tmp/sub"))
        storage.directoryContents = TranscriptDirectoryContents(folders: [folder], transcripts: [transcript])

        let vm = TranscriptListViewModel(storage: storage)
        vm.load()

        // Wait for async Task to complete
        try await Task.sleep(for: .milliseconds(100))

        XCTAssertEqual(vm.folders.count, 1)
        XCTAssertEqual(vm.folders.first?.name, "sub")
        XCTAssertEqual(vm.transcripts.count, 1)
        XCTAssertEqual(vm.transcripts.first?.name, "Test")
        XCTAssertNil(vm.errorMessage)
    }

    func testLoadSetsErrorOnFailure() async throws {
        let storage = MockTranscriptionStorage()
        storage.shouldThrowOnList = true

        let vm = TranscriptListViewModel(storage: storage)
        vm.load()

        try await Task.sleep(for: .milliseconds(100))

        XCTAssertNotNil(vm.errorMessage)
        XCTAssertEqual(vm.errorMessage, "mock error")
    }

    // MARK: - navigateInto / goBack

    func testNavigateIntoAndGoBack() async throws {
        let storage = MockTranscriptionStorage()
        let vm = TranscriptListViewModel(storage: storage)

        let folder = Folder(url: URL(fileURLWithPath: "/tmp/subfolder"))
        vm.navigateInto(folder)

        XCTAssertTrue(vm.navigation.canGoBack)
        XCTAssertEqual(vm.navigation.currentDirectory.lastPathComponent, "subfolder")

        vm.goBack()

        XCTAssertFalse(vm.navigation.canGoBack)
    }

    // MARK: - delete

    func testDeleteRemovesTranscriptFromList() async throws {
        let storage = MockTranscriptionStorage()
        let transcript = makeTranscript()
        storage.directoryContents = TranscriptDirectoryContents(folders: [], transcripts: [transcript])

        let vm = TranscriptListViewModel(storage: storage)
        vm.load()
        try await Task.sleep(for: .milliseconds(100))

        XCTAssertEqual(vm.transcripts.count, 1)

        vm.delete(transcript)
        try await Task.sleep(for: .milliseconds(100))

        XCTAssertEqual(vm.transcripts.count, 0)
        XCTAssertEqual(storage.deletedTranscripts.count, 1)
    }

    func testDeleteSetsErrorOnFailure() async throws {
        let storage = MockTranscriptionStorage()
        storage.shouldThrowOnDelete = true

        let transcript = makeTranscript()
        let vm = TranscriptListViewModel(storage: storage)

        // Manually set transcript so we can delete it
        storage.directoryContents = TranscriptDirectoryContents(folders: [], transcripts: [transcript])
        vm.load()
        try await Task.sleep(for: .milliseconds(100))

        vm.delete(transcript)
        try await Task.sleep(for: .milliseconds(100))

        XCTAssertNotNil(vm.errorMessage)
    }

    // MARK: - rename

    func testRenameUpdatesTranscriptInList() async throws {
        let storage = MockTranscriptionStorage()
        let transcript = makeTranscript(name: "Original")
        storage.directoryContents = TranscriptDirectoryContents(folders: [], transcripts: [transcript])

        let vm = TranscriptListViewModel(storage: storage)
        vm.load()
        try await Task.sleep(for: .milliseconds(100))

        vm.rename(transcript, to: "Renamed")
        try await Task.sleep(for: .milliseconds(100))

        XCTAssertEqual(vm.transcripts.first?.name, "Renamed")
        XCTAssertNil(vm.errorMessage)
    }

    func testRenameWithEmptyNameDoesNothing() async throws {
        let storage = MockTranscriptionStorage()
        let transcript = makeTranscript()
        storage.directoryContents = TranscriptDirectoryContents(folders: [], transcripts: [transcript])

        let vm = TranscriptListViewModel(storage: storage)
        vm.load()
        try await Task.sleep(for: .milliseconds(100))

        vm.rename(transcript, to: "   ")
        try await Task.sleep(for: .milliseconds(100))

        XCTAssertTrue(storage.renamedPairs.isEmpty)
        XCTAssertEqual(vm.transcripts.first?.name, "Test")
    }

    func testRenameSetsErrorOnFailure() async throws {
        let storage = MockTranscriptionStorage()
        storage.shouldThrowOnRename = true
        let transcript = makeTranscript()
        storage.directoryContents = TranscriptDirectoryContents(folders: [], transcripts: [transcript])

        let vm = TranscriptListViewModel(storage: storage)
        vm.load()
        try await Task.sleep(for: .milliseconds(100))

        vm.rename(transcript, to: "New")
        try await Task.sleep(for: .milliseconds(100))

        XCTAssertNotNil(vm.errorMessage)
    }
}
