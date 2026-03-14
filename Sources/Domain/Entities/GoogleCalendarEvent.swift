import Foundation

struct GoogleCalendarEvent: Sendable {
    let id: String
    let summary: String
    let start: Date
    let end: Date
    let attendees: [Attendee]

    struct Attendee: Sendable {
        let email: String
        let displayName: String?
    }
}
