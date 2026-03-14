import SwiftUI

struct CalendarLinkSheet: View {
    let folder: FolderItem
    var onDismiss: () -> Void

    @State private var config = MeetingConfig()
    @State private var eventName = ""

    var body: some View {
        VStack(spacing: 16) {
            HStack {
                Text("Événement Calendar lié")
                    .font(.headline)
                Spacer()
                Button("Fermer") { onDismiss() }
                    .keyboardShortcut(.cancelAction)
            }

            HStack(spacing: 8) {
                Image(systemName: "calendar")
                    .foregroundStyle(.secondary)
                TextField("Nom de l'événement Calendar", text: $eventName)
                    .textFieldStyle(.roundedBorder)
                    .onSubmit { saveLink() }
                if !eventName.isEmpty {
                    Button {
                        eventName = ""
                        saveLink()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                }
            }

            Text("L'enregistrement démarrera automatiquement dans ce dossier quand un événement Calendar porte ce nom.")
                .font(.caption)
                .foregroundStyle(.secondary)

            Spacer()
        }
        .padding()
        .frame(width: 450, height: 180)
        .onAppear {
            config = MeetingConfig.load(from: folder.url)
            eventName = config.calendarEventName ?? ""
        }
    }

    private func saveLink() {
        let trimmed = eventName.trimmingCharacters(in: .whitespaces)
        config.calendarEventName = trimmed.isEmpty ? nil : trimmed
        config.save(to: folder.url)
    }
}
