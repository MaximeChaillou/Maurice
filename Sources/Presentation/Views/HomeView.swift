import AppKit
import SwiftUI

struct HomeView: View {
    let calendarViewModel: GoogleCalendarViewModel
    let coordinator: NavigationCoordinator
    let templateUpdateService: TemplateUpdateService
    let settingsNavigator: SettingsNavigator
    var hasMeetings: Bool = false
    var hasPeople: Bool = false
    let now: Date

    private var nextEvent: GoogleCalendarEvent? {
        calendarViewModel.upcomingEvents.first { $0.start > now }
    }

    private var schedule: HomeSchedule.DayEvents {
        HomeSchedule.dayEvents(from: calendarViewModel.upcomingEvents, now: now)
    }

    private var timeUntilNextEventText: String? {
        guard let event = nextEvent,
              let breakdown = HomeSchedule.timeBreakdown(from: event.start, now: now)
        else { return nil }
        var parts: [String] = []
        if breakdown.days > 0 { parts.append(String(localized: "\(breakdown.days) d")) }
        if breakdown.hours > 0 { parts.append(String(localized: "\(breakdown.hours) h")) }
        parts.append(String(localized: "\(breakdown.minutes) min"))
        return parts.joined(separator: " ")
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            if templateUpdateService.hasPendingUpdates {
                HomeTemplateUpdatesBanner(settingsNavigator: settingsNavigator)
            }

            HomeGreetingStrip(
                now: now,
                timeUntilNextEventText: timeUntilNextEventText
            )

            GeometryReader { geo in
                let gap: CGFloat = 16
                let total = max(0, geo.size.width - gap)
                let leftWidth = total * (1.25 / 2.25)
                let rightWidth = total - leftWidth
                HStack(alignment: .top, spacing: gap) {
                    HomeSchedulePanel(
                        isConnected: calendarViewModel.isConnected,
                        isLoading: calendarViewModel.isConnected && calendarViewModel.lastRefreshDate == nil,
                        upcomingEvents: calendarViewModel.upcomingEvents,
                        displayedEvents: schedule.events,
                        isShowingTomorrow: schedule.isShowingTomorrow,
                        nextEventId: nextEvent?.id,
                        settingsNavigator: settingsNavigator
                    )
                    .frame(width: leftWidth, height: geo.size.height)

                    HomeGettingStartedPanel(
                        hasMeetings: hasMeetings,
                        hasPeople: hasPeople,
                        coordinator: coordinator
                    )
                    .frame(width: rightWidth)
                }
            }
        }
        .padding(20)
    }
}

// MARK: - Template updates banner

private struct HomeTemplateUpdatesBanner: View {
    let settingsNavigator: SettingsNavigator
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "arrow.triangle.2.circlepath")
                .foregroundStyle(.orange)
            Text("Model updates available")
                .font(.callout)
            Button("Review") {
                settingsNavigator.selectedSection = .templateUpdates
                openWindow(id: "settings")
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .glassEffect(.regular, in: .capsule)
    }
}

// MARK: - Greeting strip

private struct HomeGreetingStrip: View {
    let now: Date
    let timeUntilNextEventText: String?

    var body: some View {
        HStack(alignment: .bottom) {
            VStack(alignment: .leading, spacing: 4) {
                Text(headerDateTimeString)
                    .font(.system(size: 11, weight: .semibold))
                    .kerning(1.3)
                    .textCase(.uppercase)
                    .foregroundStyle(.secondary)

                Text(greetingText)
                    .font(.system(size: 28, weight: .semibold))
                    .tracking(-0.5)
            }

            Spacer()

            if let text = timeUntilNextEventText {
                Text("Next meeting in **\(text)**")
                    .font(.system(size: 12.5))
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.horizontal, 8)
    }

    private var greetingText: String {
        let name = AppSettings.userName.trimmingCharacters(in: .whitespaces)
        let resolved = name.isEmpty ? NSFullUserName().components(separatedBy: " ").first ?? "" : name
        return resolved.isEmpty
            ? String(localized: "Hello.")
            : String(localized: "Hello, \(resolved).")
    }

    private var headerDateTimeString: String {
        let f = DateFormatter()
        f.locale = Locale.current
        f.dateFormat = "EEEE d MMMM · HH:mm"
        return f.string(from: now)
    }
}

// MARK: - Schedule Today panel

private struct HomeSchedulePanel: View {
    let isConnected: Bool
    let isLoading: Bool
    let upcomingEvents: [GoogleCalendarEvent]
    let displayedEvents: [GoogleCalendarEvent]
    let isShowingTomorrow: Bool
    let nextEventId: String?
    let settingsNavigator: SettingsNavigator

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
            Divider().opacity(0.5)
            content
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .glassEffect(.regular, in: .rect(cornerRadius: 14))
    }

    private var header: some View {
        HStack(spacing: 8) {
            Image(systemName: "calendar")
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(.secondary)
            Text(isShowingTomorrow ? "Tomorrow" : "Today")
                .font(.system(size: 13.5, weight: .semibold))
            Spacer()
            Text("\(displayedEvents.count) events")
                .font(.system(size: 11.5))
                .monospacedDigit()
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 14)
    }

    @ViewBuilder
    private var content: some View {
        if !isConnected {
            HomeCalendarDisconnectedState(settingsNavigator: settingsNavigator)
        } else if isLoading && upcomingEvents.isEmpty {
            ProgressView()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if displayedEvents.isEmpty {
            HomeNoEventsTodayState()
        } else {
            ScrollView {
                VStack(spacing: 0) {
                    ForEach(Array(displayedEvents.enumerated()), id: \.element.id) { index, event in
                        HomeEventRow(
                            event: event,
                            isNext: event.id == nextEventId,
                            isLast: index == displayedEvents.count - 1
                        )
                    }
                }
                .padding(8)
            }
        }
    }
}

private struct HomeCalendarDisconnectedState: View {
    let settingsNavigator: SettingsNavigator
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        VStack(spacing: 12) {
            Spacer()
            Image(systemName: "calendar.badge.exclamationmark")
                .font(.system(size: 28))
                .foregroundStyle(.secondary)
            Text("No calendar connected")
                .font(.system(size: 13.5, weight: .medium))
            Text("Connect your calendar to see your upcoming meetings and start recording automatically.")
                .font(.system(size: 11.5))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 24)
            Button("Connect Google Calendar") {
                settingsNavigator.selectedSection = .general
                openWindow(id: "settings")
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.small)
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

private struct HomeNoEventsTodayState: View {
    var body: some View {
        VStack(spacing: 8) {
            Spacer()
            Image(systemName: "calendar")
                .font(.system(size: 24))
                .foregroundStyle(.tertiary)
            Text("No events today")
                .font(.system(size: 12.5))
                .foregroundStyle(.secondary)
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Event row

private struct HomeEventRow: View {
    let event: GoogleCalendarEvent
    let isNext: Bool
    let isLast: Bool

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            timeColumn
            accentBar
            titleColumn
            Spacer(minLength: 0)
            if isNext { nextBadge }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background { rowBackground }
        .overlay(alignment: .bottom) {
            if !isLast && !isNext {
                Divider().opacity(0.4).padding(.horizontal, 12)
            }
        }
    }

    private var timeColumn: some View {
        VStack(alignment: .trailing, spacing: 1) {
            Text(DateFormatters.timeOnly.string(from: event.start))
                .font(.system(size: 13, weight: .semibold))
                .monospacedDigit()
                .foregroundStyle(isNext ? Color.cyan : .primary)
            Text(DateFormatters.timeOnly.string(from: event.end))
                .font(.system(size: 10.5))
                .monospacedDigit()
                .foregroundStyle(.tertiary)
        }
        .frame(width: 48, alignment: .trailing)
    }

    private var accentBar: some View {
        RoundedRectangle(cornerRadius: 1)
            .fill(isNext ? Color.cyan : Color.primary.opacity(0.08))
            .frame(width: 2)
            .padding(.vertical, 2)
    }

    private var titleColumn: some View {
        VStack(alignment: .leading, spacing: 1) {
            Text(event.summary)
                .font(.system(size: 13.5, weight: .medium))
                .lineLimit(1)
            if let meta = attendeeMeta {
                Text(meta)
                    .font(.system(size: 11.5))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
        }
    }

    private var nextBadge: some View {
        Text("Next")
            .font(.system(size: 10, weight: .bold))
            .kerning(0.8)
            .textCase(.uppercase)
            .foregroundStyle(Color.cyan)
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(Color.cyan.opacity(0.15), in: Capsule())
    }

    @ViewBuilder
    private var rowBackground: some View {
        if isNext {
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.cyan.opacity(0.10))
        }
    }

    private var attendeeMeta: String? {
        let people = event.attendees.filter { !$0.email.contains("resource.calendar.google.com") }
        guard !people.isEmpty else { return nil }
        let names = people.prefix(4).compactMap { attendee -> String? in
            attendee.formattedName.components(separatedBy: " ").first
        }
        return names.joined(separator: ", ")
    }
}

// MARK: - Getting started panel

private struct HomeGettingStartedPanel: View {
    let hasMeetings: Bool
    let hasPeople: Bool
    let coordinator: NavigationCoordinator

    private var doneCount: Int { (hasMeetings ? 1 : 0) + (hasPeople ? 1 : 0) }
    private var total: Int { 2 }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 10) {
                Text("Getting started")
                    .font(.system(size: 13.5, weight: .semibold))
                Spacer()
                HomeProgressIndicator(done: doneCount, total: total)
            }

            VStack(spacing: 4) {
                HomeChecklistRow(label: String(localized: "Create a meeting"), done: hasMeetings) {
                    coordinator.showHome = false
                    coordinator.activeTab = .meeting
                }
                HomeChecklistRow(label: String(localized: "Add a person"), done: hasPeople) {
                    coordinator.showHome = false
                    coordinator.activeTab = .people
                }
            }
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 14)
        .frame(maxWidth: .infinity, alignment: .topLeading)
        .glassEffect(.regular, in: .rect(cornerRadius: 14))
    }
}

private struct HomeProgressIndicator: View {
    let done: Int
    let total: Int

    var body: some View {
        HStack(spacing: 6) {
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(Color.primary.opacity(0.08))
                    .frame(width: 48, height: 4)
                Capsule()
                    .fill(Color.cyan)
                    .frame(width: 48 * (CGFloat(done) / CGFloat(max(total, 1))), height: 4)
            }
            Text("\(done)/\(total)")
                .font(.system(size: 10.5))
                .monospacedDigit()
                .foregroundStyle(.secondary)
        }
    }
}

private struct HomeChecklistRow: View {
    let label: String
    let done: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                indicator
                Text(label)
                    .font(.system(size: 12.5))
                    .strikethrough(done, color: .secondary)
                    .foregroundStyle(done ? .secondary : .primary)
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 7)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background { background }
            .opacity(done ? 0.55 : 1)
            .contentShape(RoundedRectangle(cornerRadius: 8))
        }
        .buttonStyle(.plain)
        .disabled(done)
    }

    private var indicator: some View {
        ZStack {
            Circle()
                .fill(done ? Color.cyan : Color.clear)
                .frame(width: 14, height: 14)
            Circle()
                .strokeBorder(done ? Color.clear : Color.primary.opacity(0.25), lineWidth: 1)
                .frame(width: 14, height: 14)
            if done {
                Image(systemName: "checkmark")
                    .font(.system(size: 7, weight: .bold))
                    .foregroundStyle(.white)
            }
        }
    }

    @ViewBuilder
    private var background: some View {
        if !done {
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.primary.opacity(0.04))
                .overlay {
                    RoundedRectangle(cornerRadius: 8)
                        .strokeBorder(Color.primary.opacity(0.08), lineWidth: 0.5)
                }
        }
    }
}
