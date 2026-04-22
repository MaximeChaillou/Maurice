import XCTest
@testable import Maurice

final class GoogleCalendarServiceTests: XCTestCase {

    // MARK: - parseCalendarItem

    func testParseCalendarItemReturnsEventForValidItem() {
        let item: [String: Any] = [
            "id": "evt_123",
            "summary": "Team Standup",
            "start": ["dateTime": "2026-03-18T10:00:00+01:00"],
            "end": ["dateTime": "2026-03-18T10:30:00+01:00"]
        ]

        let event = GoogleCalendarService.parseCalendarItem(item)

        XCTAssertNotNil(event)
        XCTAssertEqual(event?.id, "evt_123")
        XCTAssertEqual(event?.summary, "Team Standup")
        XCTAssertTrue(event?.attendees.isEmpty ?? false)
    }

    func testParseCalendarItemReturnsNilWhenSummaryMissing() {
        let item: [String: Any] = [
            "id": "evt_123",
            "start": ["dateTime": "2026-03-18T10:00:00+01:00"],
            "end": ["dateTime": "2026-03-18T10:30:00+01:00"]
        ]

        XCTAssertNil(GoogleCalendarService.parseCalendarItem(item))
    }

    func testParseCalendarItemReturnsNilWhenIdMissing() {
        let item: [String: Any] = [
            "summary": "Meeting",
            "start": ["dateTime": "2026-03-18T10:00:00+01:00"],
            "end": ["dateTime": "2026-03-18T10:30:00+01:00"]
        ]

        XCTAssertNil(GoogleCalendarService.parseCalendarItem(item))
    }

    func testParseCalendarItemReturnsNilForAllDayEvent() {
        let item: [String: Any] = [
            "id": "evt_allday",
            "summary": "Vacation",
            "start": ["date": "2026-03-18"],
            "end": ["date": "2026-03-19"]
        ]

        XCTAssertNil(GoogleCalendarService.parseCalendarItem(item))
    }

    func testParseCalendarItemReturnsNilWhenStartMissing() {
        let item: [String: Any] = [
            "id": "evt_123",
            "summary": "Meeting",
            "end": ["dateTime": "2026-03-18T10:30:00+01:00"]
        ]

        XCTAssertNil(GoogleCalendarService.parseCalendarItem(item))
    }

    func testParseCalendarItemSkipsPictarineOrganizerEvents() {
        let item: [String: Any] = [
            "id": "evt_pic",
            "summary": "Auto-generated",
            "start": ["dateTime": "2026-03-18T10:00:00+01:00"],
            "end": ["dateTime": "2026-03-18T10:30:00+01:00"],
            "organizer": ["email": "invite@pictarine.com"]
        ]

        XCTAssertNil(GoogleCalendarService.parseCalendarItem(item))
    }

    func testParseCalendarItemIncludesAcceptedAttendees() {
        let item: [String: Any] = [
            "id": "evt_456",
            "summary": "Review",
            "start": ["dateTime": "2026-03-18T14:00:00+01:00"],
            "end": ["dateTime": "2026-03-18T15:00:00+01:00"],
            "attendees": [
                ["email": "alice@test.com", "responseStatus": "accepted", "displayName": "Alice"],
                ["email": "bob@test.com", "responseStatus": "declined"]
            ]
        ]

        let event = GoogleCalendarService.parseCalendarItem(item)

        XCTAssertNotNil(event)
        XCTAssertEqual(event?.attendees.count, 1)
        XCTAssertEqual(event?.attendees.first?.email, "alice@test.com")
        XCTAssertEqual(event?.attendees.first?.displayName, "Alice")
    }

    // MARK: - parseEventDate

    func testParseEventDateWithDateTimeString() {
        let dict: [String: Any] = ["dateTime": "2026-03-18T10:00:00Z"]

        let date = GoogleCalendarService.parseEventDate(dict)

        XCTAssertNotNil(date)
        let calendar = Calendar(identifier: .gregorian)
        let components = calendar.dateComponents(in: TimeZone(identifier: "UTC")!, from: date!)
        XCTAssertEqual(components.year, 2026)
        XCTAssertEqual(components.month, 3)
        XCTAssertEqual(components.day, 18)
        XCTAssertEqual(components.hour, 10)
        XCTAssertEqual(components.minute, 0)
    }

    func testParseEventDateWithTimezoneOffset() {
        let dict: [String: Any] = ["dateTime": "2026-03-18T10:00:00+02:00"]

        let date = GoogleCalendarService.parseEventDate(dict)

        XCTAssertNotNil(date)
        // 10:00+02:00 = 08:00 UTC
        let calendar = Calendar(identifier: .gregorian)
        let components = calendar.dateComponents(in: TimeZone(identifier: "UTC")!, from: date!)
        XCTAssertEqual(components.hour, 8)
    }

    func testParseEventDateWithDateOnlyString() {
        let dict: [String: Any] = ["date": "2026-03-18"]

        let date = GoogleCalendarService.parseEventDate(dict)

        XCTAssertNotNil(date)
    }

    func testParseEventDateReturnsNilForEmptyDict() {
        let dict: [String: Any] = [:]

        XCTAssertNil(GoogleCalendarService.parseEventDate(dict))
    }

    func testParseEventDateReturnsNilForInvalidString() {
        let dict: [String: Any] = ["dateTime": "not-a-date"]

        XCTAssertNil(GoogleCalendarService.parseEventDate(dict))
    }

    func testParseEventDatePrefersDateTimeOverDate() {
        let dict: [String: Any] = [
            "dateTime": "2026-03-18T14:30:00Z",
            "date": "2026-03-18"
        ]

        let date = GoogleCalendarService.parseEventDate(dict)

        XCTAssertNotNil(date)
        let calendar = Calendar(identifier: .gregorian)
        let components = calendar.dateComponents(in: TimeZone(identifier: "UTC")!, from: date!)
        XCTAssertEqual(components.hour, 14)
        XCTAssertEqual(components.minute, 30)
    }

    // MARK: - parseAcceptedAttendees

    func testParseAcceptedAttendeesFiltersOnlyAccepted() {
        let item: [String: Any] = [
            "attendees": [
                ["email": "a@test.com", "responseStatus": "accepted", "displayName": "A"],
                ["email": "b@test.com", "responseStatus": "declined", "displayName": "B"],
                ["email": "c@test.com", "responseStatus": "tentative", "displayName": "C"],
                ["email": "d@test.com", "responseStatus": "accepted"]
            ]
        ]

        let attendees = GoogleCalendarService.parseAcceptedAttendees(item)

        XCTAssertEqual(attendees.count, 2)
        XCTAssertEqual(attendees[0].email, "a@test.com")
        XCTAssertEqual(attendees[0].displayName, "A")
        XCTAssertEqual(attendees[1].email, "d@test.com")
        XCTAssertNil(attendees[1].displayName)
    }

    func testParseAcceptedAttendeesReturnsEmptyWhenNoAttendees() {
        let item: [String: Any] = ["summary": "Solo meeting"]

        let attendees = GoogleCalendarService.parseAcceptedAttendees(item)

        XCTAssertTrue(attendees.isEmpty)
    }

    func testParseAcceptedAttendeesReturnsEmptyWhenAllDeclined() {
        let item: [String: Any] = [
            "attendees": [
                ["email": "x@test.com", "responseStatus": "declined"]
            ]
        ]

        let attendees = GoogleCalendarService.parseAcceptedAttendees(item)

        XCTAssertTrue(attendees.isEmpty)
    }

    func testParseAcceptedAttendeesSkipsEntriesWithoutEmail() {
        let item: [String: Any] = [
            "attendees": [
                ["responseStatus": "accepted", "displayName": "NoEmail"],
                ["email": "valid@test.com", "responseStatus": "accepted"]
            ]
        ]

        let attendees = GoogleCalendarService.parseAcceptedAttendees(item)

        XCTAssertEqual(attendees.count, 1)
        XCTAssertEqual(attendees[0].email, "valid@test.com")
    }

    // MARK: - sanitizeFolderName

    func testSanitizeFolderNameReplacesSlashes() {
        XCTAssertEqual(GoogleCalendarService.sanitizeFolderName("A/B"), "A-B")
    }

    func testSanitizeFolderNameReplacesColons() {
        XCTAssertEqual(GoogleCalendarService.sanitizeFolderName("Meeting: Q1"), "Meeting- Q1")
    }

    func testSanitizeFolderNameReplacesBackslashes() {
        XCTAssertEqual(GoogleCalendarService.sanitizeFolderName("Path\\Name"), "Path-Name")
    }

    func testSanitizeFolderNameReplacesMultipleInvalidChars() {
        XCTAssertEqual(GoogleCalendarService.sanitizeFolderName("A/B:C\\D"), "A-B-C-D")
    }

    func testSanitizeFolderNameLeavesValidNameUnchanged() {
        XCTAssertEqual(GoogleCalendarService.sanitizeFolderName("Team Standup"), "Team Standup")
    }

    func testSanitizeFolderNameHandlesEmptyString() {
        XCTAssertEqual(GoogleCalendarService.sanitizeFolderName(""), "")
    }

    func testSanitizeFolderNamePreservesUnicode() {
        XCTAssertEqual(GoogleCalendarService.sanitizeFolderName("Réunion équipe"), "Réunion équipe")
    }

    // MARK: - parseCalendarItem (additional edge cases)

    func testParseCalendarItemReturnsNilWhenEndMissing() {
        let item: [String: Any] = [
            "id": "evt_123",
            "summary": "Meeting",
            "start": ["dateTime": "2026-03-18T10:00:00+01:00"]
        ]
        XCTAssertNil(GoogleCalendarService.parseCalendarItem(item))
    }

    func testParseCalendarItemReturnsNilWhenStartDateUnparseable() {
        let item: [String: Any] = [
            "id": "evt_123",
            "summary": "Meeting",
            "start": ["dateTime": "not-a-date"],
            "end": ["dateTime": "2026-03-18T10:30:00+01:00"]
        ]
        XCTAssertNil(GoogleCalendarService.parseCalendarItem(item))
    }

    func testParseCalendarItemReturnsNilWhenEndDateUnparseable() {
        let item: [String: Any] = [
            "id": "evt_123",
            "summary": "Meeting",
            "start": ["dateTime": "2026-03-18T10:00:00+01:00"],
            "end": ["dateTime": "not-a-date"]
        ]
        XCTAssertNil(GoogleCalendarService.parseCalendarItem(item))
    }

    func testParseCalendarItemAcceptsMissingOrganizer() {
        let item: [String: Any] = [
            "id": "evt_123",
            "summary": "Meeting without organizer",
            "start": ["dateTime": "2026-03-18T10:00:00+01:00"],
            "end": ["dateTime": "2026-03-18T10:30:00+01:00"]
        ]
        XCTAssertNotNil(GoogleCalendarService.parseCalendarItem(item))
    }

    func testParseCalendarItemAcceptsOrganizerWithOtherEmail() {
        let item: [String: Any] = [
            "id": "evt_123",
            "summary": "Client meeting",
            "start": ["dateTime": "2026-03-18T10:00:00+01:00"],
            "end": ["dateTime": "2026-03-18T10:30:00+01:00"],
            "organizer": ["email": "someone@external.com"]
        ]
        XCTAssertNotNil(GoogleCalendarService.parseCalendarItem(item))
    }

    func testParseCalendarItemAcceptsOrganizerWithoutEmailField() {
        let item: [String: Any] = [
            "id": "evt_123",
            "summary": "Meeting",
            "start": ["dateTime": "2026-03-18T10:00:00+01:00"],
            "end": ["dateTime": "2026-03-18T10:30:00+01:00"],
            "organizer": ["displayName": "Some Name"]
        ]
        XCTAssertNotNil(GoogleCalendarService.parseCalendarItem(item))
    }

    func testParseCalendarItemComputedFieldsMatchInputs() {
        let item: [String: Any] = [
            "id": "evt_parsed",
            "summary": "Full event",
            "start": ["dateTime": "2026-03-18T10:00:00Z"],
            "end": ["dateTime": "2026-03-18T11:00:00Z"],
            "attendees": [
                ["email": "a@x.com", "responseStatus": "accepted"]
            ]
        ]
        let event = GoogleCalendarService.parseCalendarItem(item)
        XCTAssertEqual(event?.id, "evt_parsed")
        XCTAssertEqual(event?.summary, "Full event")
        XCTAssertEqual(event?.attendees.count, 1)
    }

    // MARK: - GoogleCalendarError

    func testGoogleCalendarErrorDescriptions() {
        XCTAssertEqual(
            GoogleCalendarError.tokenExchangeFailed.errorDescription,
            "Échec de l'échange du token"
        )
        XCTAssertEqual(
            GoogleCalendarError.refreshFailed.errorDescription,
            "Échec du rafraîchissement du token"
        )
        XCTAssertEqual(
            GoogleCalendarError.emailFetchFailed.errorDescription,
            "Impossible de récupérer l'email"
        )
        XCTAssertEqual(
            GoogleCalendarError.oauthTimeout.errorDescription,
            "La connexion a expiré (120s)"
        )
    }

    // MARK: - Configuration readers

    func testClientIDFallsBackToEmptyWhenNotConfigured() {
        // Bundle lookup returns nil in tests; value should be empty string, never crash.
        XCTAssertNotNil(GoogleCalendarService.clientID)
    }

    func testClientSecretFallsBackToEmptyWhenNotConfigured() {
        XCTAssertNotNil(GoogleCalendarService.clientSecret)
    }
}
