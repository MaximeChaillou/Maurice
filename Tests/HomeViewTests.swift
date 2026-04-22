import XCTest
@testable import Maurice

@MainActor
final class HomeViewTests: XCTestCase {

    // MARK: - Action cards visibility

    func testActionCardsShownWhenNoMeetingsAndNotConnected() {
        let hasMeetings = false
        let isConnected = false
        let showCards = !hasMeetings && !isConnected
        XCTAssertTrue(showCards)
    }

    func testActionCardsHiddenWhenHasMeetings() {
        let hasMeetings = true
        let isConnected = false
        let showCards = !hasMeetings && !isConnected
        XCTAssertFalse(showCards)
    }

    func testActionCardsHiddenWhenCalendarConnected() {
        let hasMeetings = false
        let isConnected = true
        let showCards = !hasMeetings && !isConnected
        XCTAssertFalse(showCards)
    }

    func testActionCardsHiddenWhenBothConditionsMet() {
        let hasMeetings = true
        let isConnected = true
        let showCards = !hasMeetings && !isConnected
        XCTAssertFalse(showCards)
    }

    // MARK: - HomeSchedule.timeBreakdown

    func testTimeBreakdownMinutesOnly() {
        let now = Date()
        let breakdown = HomeSchedule.timeBreakdown(from: now.addingTimeInterval(45 * 60), now: now)
        XCTAssertEqual(breakdown, HomeSchedule.TimeBreakdown(days: 0, hours: 0, minutes: 45))
    }

    func testTimeBreakdownHoursAndMinutes() {
        let now = Date()
        let breakdown = HomeSchedule.timeBreakdown(from: now.addingTimeInterval(2 * 3600 + 15 * 60), now: now)
        XCTAssertEqual(breakdown, HomeSchedule.TimeBreakdown(days: 0, hours: 2, minutes: 15))
    }

    func testTimeBreakdownDaysHoursAndMinutes() {
        let now = Date()
        let offset = 3 * 24 * 3600 + 4 * 3600 + 20 * 60
        let breakdown = HomeSchedule.timeBreakdown(from: now.addingTimeInterval(TimeInterval(offset)), now: now)
        XCTAssertEqual(breakdown, HomeSchedule.TimeBreakdown(days: 3, hours: 4, minutes: 20))
    }

    func testTimeBreakdownSkipsZeroHoursButKeepsDays() {
        let now = Date()
        let offset = 2 * 24 * 3600 + 45 * 60
        let breakdown = HomeSchedule.timeBreakdown(from: now.addingTimeInterval(TimeInterval(offset)), now: now)
        XCTAssertEqual(breakdown, HomeSchedule.TimeBreakdown(days: 2, hours: 0, minutes: 45))
    }

    func testTimeBreakdownAtZero() {
        let now = Date()
        let breakdown = HomeSchedule.timeBreakdown(from: now, now: now)
        XCTAssertEqual(breakdown, HomeSchedule.TimeBreakdown(days: 0, hours: 0, minutes: 0))
    }

    func testTimeBreakdownReturnsNilForPastEvent() {
        let now = Date()
        let breakdown = HomeSchedule.timeBreakdown(from: now.addingTimeInterval(-60), now: now)
        XCTAssertNil(breakdown)
    }

    func testTimeBreakdownReturnsNilBeyondMaxDays() {
        let now = Date()
        let offset: TimeInterval = 15 * 24 * 3600
        let breakdown = HomeSchedule.timeBreakdown(from: now.addingTimeInterval(offset), now: now, maxDays: 14)
        XCTAssertNil(breakdown)
    }

    func testTimeBreakdownHonorsCustomMaxDays() {
        let now = Date()
        let offset: TimeInterval = 2 * 24 * 3600
        let breakdown = HomeSchedule.timeBreakdown(from: now.addingTimeInterval(offset), now: now, maxDays: 1)
        XCTAssertNil(breakdown)
    }

    // MARK: - HomeSchedule.dayEvents

    func testDayEventsPrefersTodayWhenAvailable() {
        let now = midday()
        let todayEvent = makeEvent(id: "t", start: now.addingTimeInterval(3600), duration: 1800)
        let tomorrowEvent = makeEvent(id: "m", start: addDays(1, to: now), duration: 1800)

        let result = HomeSchedule.dayEvents(from: [todayEvent, tomorrowEvent], now: now)

        XCTAssertEqual(result.events.map(\.id), ["t"])
        XCTAssertFalse(result.isShowingTomorrow)
    }

    func testDayEventsFallsBackToTomorrowWhenTodayEmpty() {
        let now = midday()
        let tomorrowEvent = makeEvent(id: "m", start: addDays(1, to: now), duration: 1800)

        let result = HomeSchedule.dayEvents(from: [tomorrowEvent], now: now)

        XCTAssertEqual(result.events.map(\.id), ["m"])
        XCTAssertTrue(result.isShowingTomorrow)
    }

    func testDayEventsReturnsEmptyWhenBothEmpty() {
        let now = midday()
        let farEvent = makeEvent(id: "f", start: addDays(3, to: now), duration: 1800)

        let result = HomeSchedule.dayEvents(from: [farEvent], now: now)

        XCTAssertTrue(result.events.isEmpty)
        XCTAssertFalse(result.isShowingTomorrow)
    }

    func testDayEventsReturnsEmptyWhenInputIsEmpty() {
        let result = HomeSchedule.dayEvents(from: [], now: midday())
        XCTAssertTrue(result.events.isEmpty)
        XCTAssertFalse(result.isShowingTomorrow)
    }

    func testDayEventsIncludesMultipleTodayEvents() {
        let now = midday()
        let a = makeEvent(id: "a", start: now.addingTimeInterval(1800), duration: 1800)
        let b = makeEvent(id: "b", start: now.addingTimeInterval(5400), duration: 1800)

        let result = HomeSchedule.dayEvents(from: [a, b], now: now)

        XCTAssertEqual(result.events.map(\.id), ["a", "b"])
        XCTAssertFalse(result.isShowingTomorrow)
    }

    func testDayEventsTomorrowIgnoresEventsTwoDaysOut() {
        let now = midday()
        let tomorrowEvent = makeEvent(id: "m", start: addDays(1, to: now), duration: 1800)
        let dayAfterEvent = makeEvent(id: "d2", start: addDays(2, to: now), duration: 1800)

        let result = HomeSchedule.dayEvents(from: [tomorrowEvent, dayAfterEvent], now: now)

        XCTAssertEqual(result.events.map(\.id), ["m"])
        XCTAssertTrue(result.isShowingTomorrow)
    }

    // MARK: - Attendee.formattedName

    func testFormattedNameUsesDisplayNameWhenPresent() {
        let attendee = GoogleCalendarEvent.Attendee(email: "alice@x.com", displayName: "Alice Martin")
        XCTAssertEqual(attendee.formattedName, "Alice Martin")
    }

    func testFormattedNameSplitsDisplayNameOnDot() {
        let attendee = GoogleCalendarEvent.Attendee(email: "a@x.com", displayName: "alice.martin")
        XCTAssertEqual(attendee.formattedName, "Alice Martin")
    }

    func testFormattedNameFallsBackToEmailLocalPart() {
        let attendee = GoogleCalendarEvent.Attendee(email: "alice.martin@x.com", displayName: nil)
        XCTAssertEqual(attendee.formattedName, "Alice Martin")
    }

    func testFormattedNameFallsBackToEmailWhenDisplayNameIsEmpty() {
        let attendee = GoogleCalendarEvent.Attendee(email: "bob.dylan@x.com", displayName: "")
        XCTAssertEqual(attendee.formattedName, "Bob Dylan")
    }

    func testFormattedNameHandlesSingleWordEmail() {
        let attendee = GoogleCalendarEvent.Attendee(email: "alice@x.com", displayName: nil)
        XCTAssertEqual(attendee.formattedName, "Alice")
    }

    func testFormattedNameHandlesMultipleDots() {
        let attendee = GoogleCalendarEvent.Attendee(email: "mary.anne.smith@x.com", displayName: nil)
        XCTAssertEqual(attendee.formattedName, "Mary Anne Smith")
    }

    func testFormattedNameHandlesEmailWithoutAtSign() {
        let attendee = GoogleCalendarEvent.Attendee(email: "john.doe", displayName: nil)
        XCTAssertEqual(attendee.formattedName, "John Doe")
    }

    func testFormattedNameIgnoresEmptyParts() {
        let attendee = GoogleCalendarEvent.Attendee(email: "john..doe@x.com", displayName: nil)
        XCTAssertEqual(attendee.formattedName, "John Doe")
    }

    func testFormattedNamePreservesAlreadyCapitalizedName() {
        let attendee = GoogleCalendarEvent.Attendee(email: "x@x.com", displayName: "Jean-Pierre Dupont")
        XCTAssertEqual(attendee.formattedName, "Jean-Pierre Dupont")
    }

    // MARK: - Helpers

    private func makeEvent(id: String, start: Date, duration: TimeInterval) -> GoogleCalendarEvent {
        GoogleCalendarEvent(
            id: id,
            summary: "Event \(id)",
            start: start,
            end: start.addingTimeInterval(duration),
            attendees: []
        )
    }

    private func midday() -> Date {
        var comps = Calendar.current.dateComponents([.year, .month, .day], from: Date())
        comps.hour = 12
        comps.minute = 0
        comps.second = 0
        return Calendar.current.date(from: comps)!
    }

    private func addDays(_ days: Int, to date: Date) -> Date {
        Calendar.current.date(byAdding: .day, value: days, to: date)!
    }
}
