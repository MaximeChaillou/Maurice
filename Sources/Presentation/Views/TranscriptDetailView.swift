import SwiftUI

struct TranscriptDetailView: View {
    let transcript: StoredTranscript
    let onRename: (String) -> Void

    @State private var isEditing = false
    @State private var editedName = ""

    var body: some View {
        VStack(spacing: 0) {
            titleBar
            Divider()
            ScrollView {
                BubbleListView(entries: transcript.entries)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(.background)
    }

    private var titleBar: some View {
        Group {
            if isEditing {
                TextField("Nom", text: $editedName)
                    .textFieldStyle(.plain)
                    .font(.headline)
                    .multilineTextAlignment(.center)
                    .onSubmit { commitRename() }
                    .onExitCommand { isEditing = false }
            } else {
                Text(transcript.name)
                    .font(.headline)
                    .onTapGesture {
                        editedName = transcript.name
                        isEditing = true
                    }
            }
        }
        .padding(.vertical, 8)
        .frame(maxWidth: .infinity)
    }

    private func commitRename() {
        isEditing = false
        let trimmed = editedName.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmed.isEmpty && trimmed != transcript.name {
            onRename(trimmed)
        }
    }
}
