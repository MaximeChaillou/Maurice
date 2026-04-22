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

        var formattedName: String {
            if let raw = displayName, !raw.isEmpty {
                return Self.humanize(raw)
            }
            let localPart = email.components(separatedBy: "@").first ?? email
            return Self.humanize(localPart)
        }

        private static func humanize(_ raw: String) -> String {
            let parts = raw.components(separatedBy: ".")
                .map { $0.trimmingCharacters(in: .whitespaces) }
                .filter { !$0.isEmpty }
                .map { $0.capitalized }
            guard !parts.isEmpty else { return raw }
            return parts.joined(separator: " ")
        }
    }
}
