import SwiftUI

struct MeetingTranscriptsView: View {
    let meetingName: String

    @State private var transcripts: [StoredTranscript] = []
    @State private var selectedTranscript: URL?

    private let storage = FileTranscriptionStorage()

    var body: some View {
        HStack(spacing: 0) {
            transcriptList
                .frame(width: 220)

            Divider()

            if let url = selectedTranscript,
               let transcript = transcripts.first(where: { $0.url == url }) {
                TranscriptDetailView(transcript: transcript)
            } else {
                ContentUnavailableView(
                    "Aucun transcript sélectionné",
                    systemImage: "waveform",
                    description: Text("Sélectionnez un transcript dans la liste.")
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .onAppear { loadTranscripts() }
    }

    private var transcriptList: some View {
        List(selection: $selectedTranscript) {
            ForEach(transcripts) { transcript in
                VStack(alignment: .leading, spacing: 4) {
                    Text(transcript.name)
                        .font(.body)
                        .lineLimit(1)
                    Text(transcript.date, format: .dateTime.day().month(.abbreviated).year().hour().minute())
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .padding(.vertical, 2)
                .tag(transcript.url)
                .listRowBackground(Color.clear)
            }
            .onDelete { indexSet in
                for index in indexSet {
                    deleteTranscript(transcripts[index])
                }
            }
        }
        .scrollContentBackground(.hidden)
        .overlay {
            if transcripts.isEmpty {
                ContentUnavailableView(
                    "Aucun transcript",
                    systemImage: "waveform",
                    description: Text("Les enregistrements de cette réunion apparaîtront ici.")
                )
            }
        }
    }

    private func loadTranscripts() {
        let dir = AppSettings.transcriptsDirectory
            .appendingPathComponent(meetingName, isDirectory: true)
        let contents = storage.listDirectory(dir)
        transcripts = contents.transcripts
        if selectedTranscript == nil {
            selectedTranscript = transcripts.first?.url
        }
    }

    private func deleteTranscript(_ transcript: StoredTranscript) {
        Task {
            try? await storage.delete(transcript)
            transcripts.removeAll { $0.id == transcript.id }
            if selectedTranscript == transcript.url {
                selectedTranscript = transcripts.first?.url
            }
        }
    }

    private func renameTranscript(_ transcript: StoredTranscript, to newName: String) {
        Task {
            if let updated = try? await storage.rename(transcript, to: newName) {
                if let index = transcripts.firstIndex(where: { $0.id == transcript.id }) {
                    transcripts[index] = updated
                    selectedTranscript = updated.url
                }
            }
        }
    }
}
