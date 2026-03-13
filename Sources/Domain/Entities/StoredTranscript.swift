import Foundation

struct StoredTranscript: Identifiable, Sendable {
    let id: URL
    let name: String
    let date: Date
    let entries: [TranscriptLine]

    var url: URL { id }
}

enum TranscriptLine: Sendable, Equatable {
    case text(String)
    case separator(String)
}
