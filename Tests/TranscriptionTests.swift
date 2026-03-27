import XCTest
@testable import Maurice

final class TranscriptionTests: XCTestCase {

    // MARK: - fullText

    func testFullTextJoinsEntries() {
        let entries = [
            TranscriptionEntry(id: UUID(), text: "Hello", timestamp: 0),
            TranscriptionEntry(id: UUID(), text: "world", timestamp: 1)
        ]
        let transcription = Transcription(entries: entries)
        XCTAssertEqual(transcription.fullText, "Hello world")
    }

    func testFullTextEmpty() {
        let transcription = Transcription()
        XCTAssertEqual(transcription.fullText, "")
    }

    func testFullTextSingleEntry() {
        let entries = [TranscriptionEntry(id: UUID(), text: "Only one", timestamp: 0)]
        let transcription = Transcription(entries: entries)
        XCTAssertEqual(transcription.fullText, "Only one")
    }

    // MARK: - Codable

    func testCodableRoundtrip() throws {
        let original = Transcription(
            id: UUID(),
            entries: [
                TranscriptionEntry(id: UUID(), text: "Test", timestamp: 5.0)
            ],
            startDate: Date(timeIntervalSince1970: 1_000_000),
            endDate: Date(timeIntervalSince1970: 1_001_000)
        )
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(Transcription.self, from: data)
        XCTAssertEqual(decoded.id, original.id)
        XCTAssertEqual(decoded.entries.count, 1)
        XCTAssertEqual(decoded.entries[0].text, "Test")
        XCTAssertEqual(decoded.entries[0].timestamp, 5.0)
        XCTAssertEqual(decoded.startDate, original.startDate)
        XCTAssertEqual(decoded.endDate, original.endDate)
    }

    func testCodableWithNilEndDate() throws {
        let original = Transcription(endDate: nil)
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(Transcription.self, from: data)
        XCTAssertNil(decoded.endDate)
    }

    // MARK: - Default Init

    func testDefaultInit() {
        let transcription = Transcription()
        XCTAssertTrue(transcription.entries.isEmpty)
        XCTAssertNil(transcription.endDate)
    }

    // MARK: - TranscriptionEntry

    func testTranscriptionEntryCodable() throws {
        let entry = TranscriptionEntry(id: UUID(), text: "Bonjour", timestamp: 42.5)
        let data = try JSONEncoder().encode(entry)
        let decoded = try JSONDecoder().decode(TranscriptionEntry.self, from: data)
        XCTAssertEqual(decoded.id, entry.id)
        XCTAssertEqual(decoded.text, "Bonjour")
        XCTAssertEqual(decoded.timestamp, 42.5)
    }

    // MARK: - TranscriptionEvent

    func testTranscriptionEventEntry() {
        let entry = TranscriptionEntry(id: UUID(), text: "Test", timestamp: 0)
        let event = TranscriptionEvent.entry(entry)
        if case .entry(let e) = event {
            XCTAssertEqual(e.text, "Test")
        } else {
            XCTFail("Expected .entry case")
        }
    }

    func testTranscriptionEventVolatile() {
        let event = TranscriptionEvent.volatile("partial...")
        if case .volatile(let text) = event {
            XCTAssertEqual(text, "partial...")
        } else {
            XCTFail("Expected .volatile case")
        }
    }

    func testTranscriptionEventError() {
        let event = TranscriptionEvent.error("Something failed")
        if case .error(let msg) = event {
            XCTAssertEqual(msg, "Something failed")
        } else {
            XCTFail("Expected .error case")
        }
    }
}
