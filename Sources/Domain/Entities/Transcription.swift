import Foundation

struct Transcription: Identifiable, Codable, Sendable {
    let id: UUID
    var entries: [TranscriptionEntry]
    let startDate: Date
    var endDate: Date?

    var fullText: String {
        entries.map(\.text).joined(separator: " ")
    }

    init(id: UUID = UUID(), entries: [TranscriptionEntry] = [], startDate: Date = .now, endDate: Date? = nil) {
        self.id = id
        self.entries = entries
        self.startDate = startDate
        self.endDate = endDate
    }
}
