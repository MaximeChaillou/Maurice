import SwiftUI

struct DateTranscriptsView: View {
    let meetingName: String
    let noteDate: Date

    @State private var transcripts: [StoredTranscript] = []
    @State private var selectedIndex: Int = 0

    private let storage = FileTranscriptionStorage()

    var body: some View {
        if transcripts.isEmpty {
            ContentUnavailableView(
                "Aucun transcript",
                systemImage: "waveform",
                description: Text("Pas de transcript pour cette date.")
            )
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .onAppear { loadTranscripts() }
            .onChange(of: noteDate) { loadTranscripts() }
        } else if transcripts.count == 1, let transcript = transcripts.first {
            TranscriptDetailView(transcript: transcript)
            .onAppear { loadTranscripts() }
            .onChange(of: noteDate) { loadTranscripts() }
        } else {
            VStack(spacing: 0) {
                transcriptPicker
                Divider()

                let safe = min(selectedIndex, transcripts.count - 1)
                let transcript = transcripts[max(safe, 0)]
                TranscriptDetailView(transcript: transcript)
                .id(transcript.id)
            }
            .onAppear { loadTranscripts() }
            .onChange(of: noteDate) { loadTranscripts() }
        }
    }

    private var transcriptPicker: some View {
        HStack(spacing: 12) {
            Button {
                if selectedIndex > 0 { selectedIndex -= 1 }
            } label: {
                Image(systemName: "chevron.left")
                    .font(.caption)
            }
            .buttonStyle(.plain)
            .disabled(selectedIndex <= 0)

            Text("\(selectedIndex + 1) / \(transcripts.count)")
                .font(.caption)
                .foregroundStyle(.secondary)

            Button {
                if selectedIndex < transcripts.count - 1 { selectedIndex += 1 }
            } label: {
                Image(systemName: "chevron.right")
                    .font(.caption)
            }
            .buttonStyle(.plain)
            .disabled(selectedIndex >= transcripts.count - 1)
        }
        .padding(.vertical, 6)
    }

    private func loadTranscripts() {
        let dir = AppSettings.transcriptsDirectory
            .appendingPathComponent(meetingName, isDirectory: true)
        let all = storage.listDirectory(dir).transcripts
        let calendar = Calendar.current

        transcripts = all.filter { calendar.isDate($0.date, inSameDayAs: noteDate) }
        selectedIndex = 0
    }

    private func renameTranscript(_ transcript: StoredTranscript, to newName: String) {
        Task {
            if let updated = try? await storage.rename(transcript, to: newName) {
                if let index = transcripts.firstIndex(where: { $0.id == transcript.id }) {
                    transcripts[index] = updated
                }
            }
        }
    }
}
