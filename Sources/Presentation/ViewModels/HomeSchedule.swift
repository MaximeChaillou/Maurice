import Foundation

enum HomeSchedule {
    struct TimeBreakdown: Equatable {
        let days: Int
        let hours: Int
        let minutes: Int
    }

    struct DayEvents {
        let events: [GoogleCalendarEvent]
        let isShowingTomorrow: Bool
    }

    static func dayEvents(
        from upcoming: [GoogleCalendarEvent],
        now: Date,
        calendar: Calendar = .current
    ) -> DayEvents {
        let today = upcoming.filter { calendar.isDate($0.start, inSameDayAs: now) }
        if !today.isEmpty {
            return DayEvents(events: today, isShowingTomorrow: false)
        }
        guard let nextDay = calendar.date(byAdding: .day, value: 1, to: now) else {
            return DayEvents(events: [], isShowingTomorrow: false)
        }
        let tomorrow = upcoming.filter { calendar.isDate($0.start, inSameDayAs: nextDay) }
        return DayEvents(events: tomorrow, isShowingTomorrow: !tomorrow.isEmpty)
    }

    static func timeBreakdown(
        from start: Date,
        now: Date,
        maxDays: Int = 14
    ) -> TimeBreakdown? {
        let totalMinutes = Int(start.timeIntervalSince(now) / 60.0)
        guard totalMinutes >= 0, totalMinutes <= maxDays * 24 * 60 else { return nil }
        return TimeBreakdown(
            days: totalMinutes / (24 * 60),
            hours: (totalMinutes % (24 * 60)) / 60,
            minutes: totalMinutes % 60
        )
    }
}
