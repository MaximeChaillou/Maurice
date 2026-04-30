import XCTest
@testable import Maurice

final class LinkedEventInfoTests: XCTestCase {

    private let calendar = Calendar(identifier: .gregorian)

    private func event(
        summary: String,
        start: Date,
        durationMinutes: Int = 30
    ) -> GoogleCalendarEvent {
        GoogleCalendarEvent(
            id: UUID().uuidString,
            summary: summary,
            start: start,
            end: start.addingTimeInterval(TimeInterval(durationMinutes * 60)),
            attendees: []
        )
    }

    // MARK: - findUpcomingEvent

    func testFindUpcomingEventMatchesByName() {
        let now = Date()
        let next = event(summary: "Standup", start: now.addingTimeInterval(600))
        let other = event(summary: "Lunch", start: now.addingTimeInterval(3600))

        let result = LinkedEventInfo.findUpcomingEvent(
            named: "Standup", in: [next, other], after: now
        )

        XCTAssertEqual(result?.id, next.id)
    }

    func testFindUpcomingEventIsCaseInsensitive() {
        let now = Date()
        let next = event(summary: "Standup", start: now.addingTimeInterval(600))

        let result = LinkedEventInfo.findUpcomingEvent(
            named: "STANDUP", in: [next], after: now
        )

        XCTAssertEqual(result?.id, next.id)
    }

    func testFindUpcomingEventReturnsCurrentOngoingEvent() {
        let now = Date()
        // Started 5 min ago, ends 10 min from now
        let ongoing = event(
            summary: "Meeting",
            start: now.addingTimeInterval(-300),
            durationMinutes: 15
        )

        let result = LinkedEventInfo.findUpcomingEvent(
            named: "Meeting", in: [ongoing], after: now
        )

        XCTAssertEqual(result?.id, ongoing.id)
    }

    func testFindUpcomingEventSkipsPastEvents() {
        let now = Date()
        let past = event(
            summary: "Standup",
            start: now.addingTimeInterval(-7200),
            durationMinutes: 30
        )

        let result = LinkedEventInfo.findUpcomingEvent(
            named: "Standup", in: [past], after: now
        )

        XCTAssertNil(result)
    }

    func testFindUpcomingEventReturnsNilWhenNameIsNil() {
        let now = Date()
        let next = event(summary: "Standup", start: now.addingTimeInterval(600))

        XCTAssertNil(LinkedEventInfo.findUpcomingEvent(named: nil, in: [next], after: now))
    }

    func testFindUpcomingEventReturnsNilWhenNameIsEmpty() {
        let now = Date()
        let next = event(summary: "Standup", start: now.addingTimeInterval(600))

        XCTAssertNil(LinkedEventInfo.findUpcomingEvent(named: "", in: [next], after: now))
    }

    func testFindUpcomingEventReturnsNilWhenNoMatch() {
        let now = Date()
        let other = event(summary: "Lunch", start: now.addingTimeInterval(600))

        XCTAssertNil(LinkedEventInfo.findUpcomingEvent(named: "Standup", in: [other], after: now))
    }

    // MARK: - statusLabel

    func testStatusLabelReturnsNilWhenNoEvent() {
        XCTAssertNil(LinkedEventInfo.statusLabel(event: nil, now: Date()))
    }

    func testStatusLabelNowWhenEventOngoing() {
        let now = Date()
        let ongoing = event(
            summary: "Standup",
            start: now.addingTimeInterval(-300),
            durationMinutes: 15
        )

        let label = LinkedEventInfo.statusLabel(event: ongoing, now: now)

        XCTAssertEqual(label, String(localized: "Now"))
    }

    func testStatusLabelInMinutesWhenEventStartsSoon() {
        let now = Date()
        let next = event(summary: "Standup", start: now.addingTimeInterval(12 * 60 + 5))

        let label = LinkedEventInfo.statusLabel(event: next, now: now)

        // Localized format varies (en: "Next · in 12 min", fr: "Prochain · dans 12 min").
        // Just check the minute count is rendered and the label is the "soon" branch
        // (i.e. not the same as "Now" / a HH:mm time label).
        XCTAssertNotNil(label)
        XCTAssertTrue(label?.contains("12") ?? false,
                      "Expected minute count in label, got: \(label ?? "nil")")
        XCTAssertTrue(label?.contains("min") ?? false,
                      "Expected 'min' unit in label, got: \(label ?? "nil")")
        XCTAssertNotEqual(label, String(localized: "Now"))
    }

    func testStatusLabelTodayWhenSameDayLater() throws {
        var components = DateComponents()
        components.year = 2026
        components.month = 5
        components.day = 4
        components.hour = 9
        components.minute = 0
        let now = try XCTUnwrap(calendar.date(from: components))
        let later = try XCTUnwrap(calendar.date(byAdding: .hour, value: 5, to: now))
        let next = event(summary: "Standup", start: later)

        let label = LinkedEventInfo.statusLabel(event: next, now: now, calendar: calendar)

        // Same day, > 60 min away → "today" branch with HH:mm time.
        XCTAssertNotNil(label)
        XCTAssertTrue(label?.contains("14:00") ?? false,
                      "Expected event time in label, got: \(label ?? "nil")")
    }

    func testStatusLabelTomorrow() throws {
        var components = DateComponents()
        components.year = 2026
        components.month = 5
        components.day = 4
        components.hour = 9
        components.minute = 0
        let now = try XCTUnwrap(calendar.date(from: components))
        let tomorrow = try XCTUnwrap(calendar.date(byAdding: .day, value: 1, to: now))
        let next = event(summary: "Standup", start: tomorrow)

        let label = LinkedEventInfo.statusLabel(event: next, now: now, calendar: calendar)

        XCTAssertNotNil(label)
        XCTAssertTrue(label?.contains("09:00") ?? false,
                      "Expected event time in label, got: \(label ?? "nil")")
    }

    func testStatusLabelLaterDate() throws {
        var components = DateComponents()
        components.year = 2026
        components.month = 5
        components.day = 4
        components.hour = 9
        components.minute = 0
        let now = try XCTUnwrap(calendar.date(from: components))
        let later = try XCTUnwrap(calendar.date(byAdding: .day, value: 3, to: now))
        let next = event(summary: "Standup", start: later)

        let label = LinkedEventInfo.statusLabel(event: next, now: now, calendar: calendar)

        // 3 days away → "EEE HH:mm" formatted segment.
        XCTAssertNotNil(label)
        XCTAssertTrue(label?.contains("09:00") ?? false,
                      "Expected event time in label, got: \(label ?? "nil")")
    }

    // MARK: - timeLabel

    func testTimeLabelReturnsNilWhenNoEvent() {
        XCTAssertNil(LinkedEventInfo.timeLabel(event: nil))
    }

    func testTimeLabelFormatsRange() {
        var components = DateComponents()
        components.year = 2026
        components.month = 4
        components.day = 17
        components.hour = 10
        components.minute = 0
        let start = calendar.date(from: components)!
        let evt = event(summary: "Standup", start: start, durationMinutes: 15)

        let label = LinkedEventInfo.timeLabel(event: evt)

        XCTAssertNotNil(label)
        // Format: "EEE d MMM · HH:mm – HH:mm"
        XCTAssertTrue(label?.contains("·") ?? false)
        XCTAssertTrue(label?.contains("–") ?? false)
        XCTAssertTrue(label?.contains("10:00") ?? false)
        XCTAssertTrue(label?.contains("10:15") ?? false)
    }
}
