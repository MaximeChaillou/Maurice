import XCTest
@testable import Maurice

final class EntryDeleteActionTests: XCTestCase {

    private func makeEntry(dateString: String = "2026-03-27") -> MeetingDateEntry {
        MeetingDateEntry(dateString: dateString, date: Date(), noteFile: nil, transcript: nil)
    }

    // MARK: - Entry Accessor

    func testNoteActionEntry() {
        let entry = makeEntry()
        let action = EntryDeleteAction.note(entry)
        XCTAssertEqual(action.entry.dateString, "2026-03-27")
    }

    func testTranscriptActionEntry() {
        let entry = makeEntry()
        let action = EntryDeleteAction.transcript(entry)
        XCTAssertEqual(action.entry.dateString, "2026-03-27")
    }

    func testBothActionEntry() {
        let entry = makeEntry()
        let action = EntryDeleteAction.both(entry)
        XCTAssertEqual(action.entry.dateString, "2026-03-27")
    }

    // MARK: - Messages

    func testNoteMessage() {
        let entry = makeEntry(dateString: "2026-03-15")
        let action = EntryDeleteAction.note(entry)
        XCTAssertTrue(action.message.contains("note"))
        XCTAssertTrue(action.message.contains("2026-03-15"))
    }

    func testTranscriptMessage() {
        let entry = makeEntry(dateString: "2026-03-15")
        let action = EntryDeleteAction.transcript(entry)
        XCTAssertTrue(action.message.contains("transcript"))
        XCTAssertTrue(action.message.contains("2026-03-15"))
    }

    func testBothMessage() {
        let entry = makeEntry(dateString: "2026-03-15")
        let action = EntryDeleteAction.both(entry)
        XCTAssertTrue(action.message.contains("note"))
        XCTAssertTrue(action.message.contains("transcript"))
        XCTAssertTrue(action.message.contains("2026-03-15"))
    }
}
