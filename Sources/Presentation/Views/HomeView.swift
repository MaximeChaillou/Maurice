import SwiftUI

struct HomeView: View {
    let calendarViewModel: GoogleCalendarViewModel
    @State private var upcomingEvents: [GoogleCalendarEvent] = []
    @State private var isLoading = false

    var body: some View {
        VStack(spacing: 24) {
            Spacer()

            Image(systemName: "waveform.circle.fill")
                .font(.system(size: 64))
                .foregroundStyle(.secondary)

            Text("Bienvenue dans Maurice")
                .font(.largeTitle.weight(.semibold))

            Text("Votre assistant de transcription de réunions")
                .font(.title3)
                .foregroundStyle(.secondary)

            if calendarViewModel.isConnected {
                upcomingEventsSection
            }

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .task {
            await loadEvents()
        }
    }

    private var upcomingEventsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "calendar")
                    .foregroundStyle(.secondary)
                Text("Prochaines réunions")
                    .font(.headline)
            }

            if isLoading {
                ProgressView()
                    .frame(maxWidth: .infinity)
            } else if upcomingEvents.isEmpty {
                Text("Aucune réunion prévue")
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity)
            } else {
                VStack(spacing: 8) {
                    ForEach(upcomingEvents, id: \.id) { event in
                        eventRow(event)
                    }
                }
            }
        }
        .padding(20)
        .frame(maxWidth: 500)
        .glassEffect(.regular, in: .rect(cornerRadius: 12))
    }

    private func eventRow(_ event: GoogleCalendarEvent) -> some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(event.summary)
                    .font(.body.weight(.medium))
                    .lineLimit(1)
                Text(formatEventTime(event))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
        }
        .padding(.vertical, 4)
    }

    private func formatEventTime(_ event: GoogleCalendarEvent) -> String {
        let calendar = Calendar.current

        if calendar.isDateInToday(event.start) {
            let t = DateFormatters.timeOnly
            return "Aujourd'hui \(t.string(from: event.start)) – \(t.string(from: event.end))"
        } else if calendar.isDateInTomorrow(event.start) {
            let t = DateFormatters.timeOnly
            return "Demain \(t.string(from: event.start)) – \(t.string(from: event.end))"
        } else {
            let f = DateFormatter()
            f.dateFormat = "EEEE d MMM, HH:mm"
            f.locale = Locale(identifier: "fr_FR")
            return f.string(from: event.start)
        }
    }

    private func loadEvents() async {
        isLoading = true
        upcomingEvents = await calendarViewModel.upcomingEvents()
        isLoading = false
    }
}
