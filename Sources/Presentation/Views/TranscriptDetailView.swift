import SwiftUI

struct TranscriptDetailView: View {
    let transcript: StoredTranscript

    var body: some View {
        ScrollView {
            BubbleListView(entries: transcript.entries)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
