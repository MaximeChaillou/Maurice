import SwiftUI

struct CalendarLinkSheet: View {
    let folder: FolderItem
    var onDismiss: () -> Void

    @State private var config = MeetingConfig()
    @State private var eventName = ""

    var body: some View {
        VStack(spacing: 16) {
            HStack {
                Text("Linked Calendar event")
                    .font(.headline)
                Spacer()
                Button("Close") { onDismiss() }
                    .keyboardShortcut(.cancelAction)
            }

            HStack(spacing: 8) {
                Image(systemName: "calendar")
                    .foregroundStyle(.secondary)
                TextField("Calendar event name", text: $eventName)
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

            Text("Recording will start automatically in this folder when a Calendar event has this name.")
                .font(.caption)
                .foregroundStyle(.secondary)

            Spacer()
        }
        .padding()
        .frame(width: 450, height: 180)
        .onAppear {
            Task {
                config = await MeetingConfig.loadAsync(from: folder.url)
                eventName = config.calendarEventName ?? ""
            }
        }
    }

    private func saveLink() {
        let trimmed = eventName.trimmingCharacters(in: .whitespaces)
        config.calendarEventName = trimmed.isEmpty ? nil : trimmed
        config.saveAsync(to: folder.url)
    }
}
