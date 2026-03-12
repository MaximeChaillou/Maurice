import Foundation

struct StoredTranscript: Identifiable, Sendable {
    let id: URL
    let name: String
    let date: Date
    let entries: [String]

    var url: URL { id }
}
