import Foundation

/// Helpers that turn a Google Calendar event linked to a meeting/1-1 folder
/// into the status pill + time meta strings used in the doc header.
enum LinkedEventInfo {

    /// Looks up the next upcoming event whose `summary` matches `eventName`
    /// (case-insensitive) and that has not yet ended at `now`.
    static func findUpcomingEvent(
        named eventName: String?,
        in events: [GoogleCalendarEvent],
        after now: Date
    ) -> GoogleCalendarEvent? {
        guard let eventName, !eventName.isEmpty else { return nil }
        return events.first { event in
            event.summary.localizedCaseInsensitiveCompare(eventName) == .orderedSame
                && event.end > now
        }
    }

    /// "Now" / "Next · in 12 min" / "Next · today 14:30" / "Next · Mon 14:30".
    /// Returns `nil` when there is no linked upcoming event.
    static func statusLabel(
        event: GoogleCalendarEvent?,
        now: Date,
        calendar: Calendar = .current
    ) -> String? {
        guard let event else { return nil }
        if event.start <= now && event.end > now {
            return String(localized: "Now")
        }
        let minutes = Int(event.start.timeIntervalSince(now) / 60)
        if minutes >= 0 && minutes < 60 {
            return String(localized: "Next · in \(minutes) min")
        }
        let formatter = DateFormatter()
        formatter.locale = Locale.current
        if calendar.isDateInToday(event.start) {
            formatter.dateFormat = "HH:mm"
            return String(localized: "Next · today \(formatter.string(from: event.start))")
        }
        if calendar.isDateInTomorrow(event.start) {
            formatter.dateFormat = "HH:mm"
            return String(localized: "Next · tomorrow \(formatter.string(from: event.start))")
        }
        formatter.dateFormat = "EEE HH:mm"
        return String(localized: "Next · \(formatter.string(from: event.start))")
    }

    /// "Thu Apr 17 · 10:00 – 10:15" — used as a meta item in the doc header.
    static func timeLabel(event: GoogleCalendarEvent?) -> String? {
        guard let event else { return nil }
        let dateFormatter = DateFormatter()
        dateFormatter.locale = Locale.current
        dateFormatter.dateFormat = "EEE d MMM"
        let timeFormatter = DateFormatter()
        timeFormatter.locale = Locale.current
        timeFormatter.dateFormat = "HH:mm"
        let day = dateFormatter.string(from: event.start)
        let start = timeFormatter.string(from: event.start)
        let end = timeFormatter.string(from: event.end)
        return "\(day) · \(start) – \(end)"
    }
}
