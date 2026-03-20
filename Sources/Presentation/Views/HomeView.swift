import SwiftUI

struct HomeView: View {
    let calendarViewModel: GoogleCalendarViewModel
    let coordinator: NavigationCoordinator
    var hasMeetings: Bool = false
    @Environment(\.openWindow) private var openWindow
    @State private var upcomingEvents: [GoogleCalendarEvent] = []
    @State private var isLoading = false

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                Spacer(minLength: 20)

                Image(systemName: "waveform.circle.fill")
                    .font(.system(size: 64))
                    .foregroundStyle(.secondary)

                Text("Bienvenue dans Maurice")
                    .font(.largeTitle.weight(.semibold))

                Text("Votre assistant de transcription de réunions")
                    .font(.title3)
                    .foregroundStyle(.secondary)

                if !hasMeetings && !calendarViewModel.isConnected {
                    actionCardsGrid
                        .padding(.top, 8)
                }

                if calendarViewModel.isConnected {
                    upcomingEventsSection
                }

                Spacer(minLength: 20)
            }
            .frame(maxWidth: .infinity)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .task {
            await loadEvents()
        }
    }

    // MARK: - Action Cards

    private var actionCardsGrid: some View {
        let columns = [
            GridItem(.flexible(), spacing: 12),
            GridItem(.flexible(), spacing: 12)
        ]
        return LazyVGrid(columns: columns, spacing: 12) {
            actionCard(
                icon: "mic.fill",
                title: "Enregistrer",
                description: "Démarrez l'enregistrement avec le bouton micro ci-dessous",
                action: nil
            )

            actionCard(
                icon: "calendar.badge.plus",
                title: "Créer une réunion",
                description: "Organisez vos réunions récurrentes (standup, 1-1…)"
            ) {
                coordinator.showHome = false
                coordinator.activeTab = .meeting
            }

            actionCard(
                icon: "person.badge.plus",
                title: "Ajouter une personne",
                description: "Notes de 1-1, évaluations et objectifs"
            ) {
                coordinator.showHome = false
                coordinator.activeTab = .people
            }

            actionCard(
                icon: "calendar",
                title: "Connecter Google Calendar",
                description: "Voyez vos prochaines réunions sur l'accueil"
            ) {
                openWindow(id: "settings")
            }
        }
        .frame(maxWidth: 500)
    }

    private func actionCard(
        icon: String,
        title: String,
        description: String,
        action: (() -> Void)?
    ) -> some View {
        Group {
            if let action {
                Button(action: action) {
                    actionCardContent(icon: icon, title: title, description: description)
                }
                .buttonStyle(.plain)
            } else {
                actionCardContent(icon: icon, title: title, description: description)
            }
        }
    }

    private func actionCardContent(icon: String, title: String, description: String) -> some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 28))
                .foregroundStyle(.secondary)

            Text(title)
                .font(.headline)

            Text(description)
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .lineLimit(2)
        }
        .frame(maxWidth: .infinity)
        .padding(16)
        .glassEffect(.regular, in: .rect(cornerRadius: 12))
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
