import XCTest
@testable import Maurice

// MARK: - Mock Service

private final class UseCaseMockService: LiveTranscriptionService, @unchecked Sendable {
    var prepareCalled = false
    var startCalled = false
    var stopCalled = false
    var onAudioLevel: (@Sendable (Float) -> Void)?

    var prepareError: Error?
    var streamToReturn: AsyncStream<TranscriptionEvent>?

    func prepare(onStateChange: @escaping @Sendable (SpeechModelState) -> Void) async throws {
        prepareCalled = true
        if let error = prepareError { throw error }
        onStateChange(.ready)
    }

    func startTranscription() async throws -> AsyncStream<TranscriptionEvent> {
        startCalled = true
        return streamToReturn ?? AsyncStream { $0.finish() }
    }

    func stopTranscription() async {
        stopCalled = true
    }
}

// MARK: - Mock Storage

private final class UseCaseMockStorage: TranscriptionStorage, @unchecked Sendable {
    var sessionURL = URL(fileURLWithPath: "/tmp/mock-session.transcript")
    var beginSessionCalledWith: (date: Date, subdirectory: String?)?
    var beginSessionError: Error?
    var appendedEntries: [(entry: TranscriptionEntry, url: URL)] = []
    var appendEntryError: Error?

    func beginLiveSession(startDate: Date, subdirectory: String?) throws -> URL {
        if let error = beginSessionError { throw error }
        beginSessionCalledWith = (startDate, subdirectory)
        return sessionURL
    }

    func appendEntry(_ entry: TranscriptionEntry, to fileURL: URL) throws {
        if let error = appendEntryError { throw error }
        appendedEntries.append((entry, fileURL))
    }

    func listDirectory(_ url: URL) async throws -> TranscriptDirectoryContents {
        TranscriptDirectoryContents(folders: [], transcripts: [])
    }

    func delete(_ transcript: StoredTranscript) async throws {}
    func rename(_ transcript: StoredTranscript, to newName: String) async throws -> StoredTranscript {
        transcript
    }
}

// MARK: - Tests

final class RecordingUseCaseTests: XCTestCase {
    private var service: UseCaseMockService!
    private var storage: UseCaseMockStorage!
    private var sut: RecordingUseCase!

    override func setUp() {
        super.setUp()
        service = UseCaseMockService()
        storage = UseCaseMockStorage()
        sut = RecordingUseCase(transcription: service, storage: storage)
    }

    override func tearDown() {
        sut = nil
        storage = nil
        service = nil
        super.tearDown()
    }

    // MARK: - prepare

    func testPrepareDelegatesToService() async throws {
        try await sut.prepare { (_: SpeechModelState) in }
        XCTAssertTrue(service.prepareCalled)
    }

    func testPrepareForwardsError() async {
        service.prepareError = NSError(domain: "test", code: 42, userInfo: nil)

        do {
            try await sut.prepare { (_: SpeechModelState) in }
            XCTFail("Expected error to be thrown")
        } catch {
            XCTAssertEqual((error as NSError).code, 42)
        }
    }

    // MARK: - startRecording

    func testStartRecordingDelegatesToService() async throws {
        service.streamToReturn = AsyncStream<TranscriptionEvent> { $0.finish() }
        _ = try await sut.startRecording()
        XCTAssertTrue(service.startCalled)
    }

    // MARK: - stopRecording

    func testStopRecordingDelegatesToService() async {
        await sut.stopRecording()
        XCTAssertTrue(service.stopCalled)
    }

    // MARK: - beginLiveSession

    func testBeginLiveSessionDelegatesToStorage() throws {
        let url = try sut.beginLiveSession(startDate: Date(), subdirectory: "Meetings/Test")
        XCTAssertEqual(url, storage.sessionURL)
        XCTAssertEqual(storage.beginSessionCalledWith?.subdirectory, "Meetings/Test")
    }

    func testBeginLiveSessionWithNilSubdirectory() throws {
        _ = try sut.beginLiveSession(startDate: Date())
        XCTAssertNil(storage.beginSessionCalledWith?.subdirectory)
    }

    func testBeginLiveSessionForwardsError() {
        storage.beginSessionError = NSError(domain: "storage", code: 1, userInfo: nil)
        XCTAssertThrowsError(try sut.beginLiveSession(startDate: Date()))
    }

    // MARK: - appendEntry

    func testAppendEntryDelegatesToStorage() throws {
        let entry = TranscriptionEntry(text: "Hello world")
        let url = URL(fileURLWithPath: "/tmp/test.transcript")
        try sut.appendEntry(entry, to: url)
        XCTAssertEqual(storage.appendedEntries.count, 1)
        XCTAssertEqual(storage.appendedEntries[0].entry.text, "Hello world")
    }

    func testAppendEntryForwardsError() {
        storage.appendEntryError = NSError(domain: "storage", code: 2, userInfo: nil)
        XCTAssertThrowsError(try sut.appendEntry(TranscriptionEntry(text: "test"), to: URL(fileURLWithPath: "/tmp/t")))
    }

    func testAppendMultipleEntries() throws {
        let url = URL(fileURLWithPath: "/tmp/test.transcript")
        try sut.appendEntry(TranscriptionEntry(text: "First"), to: url)
        try sut.appendEntry(TranscriptionEntry(text: "Second"), to: url)
        XCTAssertEqual(storage.appendedEntries.count, 2)
    }

    // MARK: - onAudioLevel

    func testOnAudioLevelSetDelegatesToService() {
        sut.onAudioLevel = { (_: Float) in }
        XCTAssertNotNil(service.onAudioLevel)
    }
}
