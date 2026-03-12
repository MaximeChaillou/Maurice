import Foundation

enum TranscriptionEvent: Sendable {
    case entry(TranscriptionEntry)
    case volatile(String)
    case error(String)
}
