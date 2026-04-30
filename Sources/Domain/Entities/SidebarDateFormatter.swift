import Foundation
import SwiftUI

/// Buckets used to group meeting folders in the sidebar by recency.
/// Today is reached when there is an upcoming calendar event today *or*
/// the most recent file is dated today. The other buckets only look at
/// the most recent file's date.
enum MeetingDateSection: Int, CaseIterable {
    case today, yesterday, thisWeek, earlier

    var title: LocalizedStringKey {
        switch self {
        case .today: "Today"
        case .yesterday: "Yesterday"
        case .thisWeek: "This week"
        case .earlier: "Earlier"
        }
    }

    static func bucket(
        lastActivity: Date?,
        hasEventToday: Bool,
        now: Date,
        calendar: Calendar = .current
    ) -> MeetingDateSection {
        if hasEventToday { return .today }
        guard let lastActivity else { return .earlier }
        if calendar.isDateInToday(lastActivity) { return .today }
        if calendar.isDateInYesterday(lastActivity) { return .yesterday }
        let nowWeek = calendar.component(.weekOfYear, from: now)
        let nowYear = calendar.component(.yearForWeekOfYear, from: now)
        let lastWeek = calendar.component(.weekOfYear, from: lastActivity)
        let lastYear = calendar.component(.yearForWeekOfYear, from: lastActivity)
        if nowWeek == lastWeek && nowYear == lastYear { return .thisWeek }
        return .earlier
    }
}

/// Compact date labels for sidebar rows.
/// `upcomingLabel` shows the time/day of an upcoming calendar event;
/// `relativeLabel` shows the most recent activity date.
enum SidebarDateFormatter {

    /// "10:00" if today, "tomorrow", otherwise "Mon 14".
    static func upcomingLabel(
        event: GoogleCalendarEvent,
        now: Date,
        calendar: Calendar = .current
    ) -> String? {
        if calendar.isDateInToday(event.start) {
            let formatter = DateFormatter()
            formatter.locale = Locale.current
            formatter.dateFormat = "HH:mm"
            return formatter.string(from: event.start)
        }
        if calendar.isDateInTomorrow(event.start) {
            return String(localized: "tomorrow")
        }
        let formatter = DateFormatter()
        formatter.locale = Locale.current
        formatter.dateFormat = "EEE d"
        return formatter.string(from: event.start)
    }

    /// "today", "yesterday", "Mon 14", "5 Apr".
    static func relativeLabel(
        date: Date,
        now: Date,
        calendar: Calendar = .current
    ) -> String? {
        if calendar.isDateInToday(date) {
            return String(localized: "today")
        }
        if calendar.isDateInYesterday(date) {
            return String(localized: "yesterday")
        }
        let daysAgo = calendar.dateComponents([.day], from: date, to: now).day ?? 0
        let formatter = DateFormatter()
        formatter.locale = Locale.current
        if daysAgo < 7 {
            formatter.dateFormat = "EEE d"
        } else {
            formatter.dateFormat = "d MMM"
        }
        return formatter.string(from: date)
    }
}
