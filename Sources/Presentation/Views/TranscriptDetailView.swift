import SwiftUI

struct TranscriptDetailView: View {
    let url: URL
    @State private var entries: [TranscriptLine] = []

    var body: some View {
        ScrollView {
            BubbleListView(entries: entries)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .task(id: url) {
            let loaded = await Task.detached {
                FileTranscriptionStorage().parseTranscriptFile(at: url)?.entries ?? []
            }.value
            entries = loaded
        }
    }
}
