import Foundation

struct TranscriptionEntry: Identifiable, Codable, Sendable {
    let id: UUID
    let text: String
    let timestamp: TimeInterval

    init(id: UUID = UUID(), text: String, timestamp: TimeInterval = 0) {
        self.id = id
        self.text = text
        self.timestamp = timestamp
    }
}
