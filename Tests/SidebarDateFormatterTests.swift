import XCTest
@testable import Maurice

final class SidebarDateFormatterTests: XCTestCase {

    private let calendar = Calendar(identifier: .gregorian)

    /// `now` is the actual current time; other dates are derived from it. The
    /// formatter relies on `calendar.isDateInToday` / `isDateInYesterday`, which
    /// always compare against the system's real `Date()` — using fixed dates
    /// would break around date rollovers, so we compute everything relative
    /// to the real now.
    private var realNow: Date { Date() }

    private func event(start: Date, durationMinutes: Int = 30) -> GoogleCalendarEvent {
        GoogleCalendarEvent(
            id: UUID().uuidString,
            summary: "Test",
            start: start,
            end: start.addingTimeInterval(TimeInterval(durationMinutes * 60)),
            attendees: []
        )
    }

    // MARK: - MeetingDateSection.bucket

    func testBucketTodayWhenEventToday() {
        let bucket = MeetingDateSection.bucket(
            lastActivity: nil,
            hasEventToday: true,
            now: realNow,
            calendar: calendar
        )
        XCTAssertEqual(bucket, .today)
    }

    func testBucketEarlierWhenNoActivityNoEvent() {
        let bucket = MeetingDateSection.bucket(
            lastActivity: nil,
            hasEventToday: false,
            now: realNow,
            calendar: calendar
        )
        XCTAssertEqual(bucket, .earlier)
    }

    func testBucketTodayWhenLastActivityToday() throws {
        let now = realNow
        let earlierToday = try XCTUnwrap(
            calendar.date(byAdding: .hour, value: -2, to: now)
        )
        let bucket = MeetingDateSection.bucket(
            lastActivity: earlierToday,
            hasEventToday: false,
            now: now,
            calendar: calendar
        )
        XCTAssertEqual(bucket, .today)
    }

    func testBucketYesterdayWhenLastActivityYesterday() throws {
        let now = realNow
        // Use the start-of-yesterday so we land squarely inside "yesterday"
        // even if `now` is just past midnight.
        let yesterdayMidday = try XCTUnwrap(
            calendar.date(byAdding: .day, value: -1,
                          to: calendar.date(bySettingHour: 12, minute: 0, second: 0, of: now)!)
        )
        let bucket = MeetingDateSection.bucket(
            lastActivity: yesterdayMidday,
            hasEventToday: false,
            now: now,
            calendar: calendar
        )
        XCTAssertEqual(bucket, .yesterday)
    }

    func testBucketEarlierWhenLastActivityWeeksAgo() throws {
        let now = realNow
        let oldDate = try XCTUnwrap(
            calendar.date(byAdding: .day, value: -45, to: now)
        )
        let bucket = MeetingDateSection.bucket(
            lastActivity: oldDate,
            hasEventToday: false,
            now: now,
            calendar: calendar
        )
        XCTAssertEqual(bucket, .earlier)
    }

    func testEventTodayWinsOverOldActivity() throws {
        let now = realNow
        let oldDate = try XCTUnwrap(
            calendar.date(byAdding: .day, value: -365, to: now)
        )
        let bucket = MeetingDateSection.bucket(
            lastActivity: oldDate,
            hasEventToday: true,
            now: now,
            calendar: calendar
        )
        XCTAssertEqual(bucket, .today)
    }

    // MARK: - SidebarDateFormatter.upcomingLabel

    func testUpcomingLabelHHMMWhenToday() throws {
        let now = realNow
        let later = try XCTUnwrap(
            calendar.date(bySettingHour: 14, minute: 30, second: 0, of: now)
        )
        let evt = event(start: later)

        let label = SidebarDateFormatter.upcomingLabel(event: evt, now: now, calendar: calendar)

        XCTAssertEqual(label, "14:30")
    }

    func testUpcomingLabelTomorrow() throws {
        let now = realNow
        let tomorrow = try XCTUnwrap(
            calendar.date(byAdding: .day, value: 1,
                          to: calendar.date(bySettingHour: 10, minute: 0, second: 0, of: now)!)
        )
        let evt = event(start: tomorrow)

        let label = SidebarDateFormatter.upcomingLabel(event: evt, now: now, calendar: calendar)

        XCTAssertEqual(label, String(localized: "tomorrow"))
    }

    func testUpcomingLabelEEEdForLaterDate() throws {
        let now = realNow
        let later = try XCTUnwrap(calendar.date(byAdding: .day, value: 4, to: now))
        let evt = event(start: later)

        let label = SidebarDateFormatter.upcomingLabel(event: evt, now: now, calendar: calendar)

        XCTAssertNotNil(label)
        // "EEE d" — should contain the day number of the future date.
        let expectedDay = String(calendar.component(.day, from: later))
        XCTAssertTrue(label?.contains(expectedDay) ?? false,
                      "Expected day \(expectedDay) in label, got: \(label ?? "nil")")
    }

    // MARK: - SidebarDateFormatter.relativeLabel

    func testRelativeLabelUsesDayMonthFormatToday() throws {
        let now = realNow
        let earlierToday = try XCTUnwrap(
            calendar.date(byAdding: .hour, value: -1, to: now)
        )

        let label = SidebarDateFormatter.relativeLabel(date: earlierToday)

        let expectedDay = String(calendar.component(.day, from: earlierToday))
        XCTAssertTrue(label?.contains(expectedDay) ?? false,
                      "Expected day \(expectedDay) in label, got: \(label ?? "nil")")
    }

    func testRelativeLabelUsesDayMonthFormatWithinAWeek() throws {
        let now = realNow
        let threeDaysAgo = try XCTUnwrap(
            calendar.date(byAdding: .day, value: -3, to: now)
        )

        let label = SidebarDateFormatter.relativeLabel(date: threeDaysAgo)

        XCTAssertNotNil(label)
        let expectedDay = String(calendar.component(.day, from: threeDaysAgo))
        XCTAssertTrue(label?.contains(expectedDay) ?? false,
                      "Expected day \(expectedDay) in label, got: \(label ?? "nil")")
    }

    func testRelativeLabelUsesDayMonthFormatForOlderDate() throws {
        let now = realNow
        let weeksAgo = try XCTUnwrap(
            calendar.date(byAdding: .day, value: -30, to: now)
        )

        let label = SidebarDateFormatter.relativeLabel(date: weeksAgo)

        XCTAssertNotNil(label)
        let expectedDay = String(calendar.component(.day, from: weeksAgo))
        XCTAssertTrue(label?.contains(expectedDay) ?? false,
                      "Expected day \(expectedDay) in label, got: \(label ?? "nil")")
    }
}
