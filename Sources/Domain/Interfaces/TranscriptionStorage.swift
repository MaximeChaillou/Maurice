import Foundation

protocol TranscriptionStorage: Sendable {
    func beginLiveSession(startDate: Date, subdirectory: String?) throws -> URL
    func appendEntry(_ entry: TranscriptionEntry, to fileURL: URL) throws
    func listDirectory(_ url: URL) async throws -> TranscriptDirectoryContents
    func delete(_ transcript: StoredTranscript) async throws
    func rename(_ transcript: StoredTranscript, to newName: String) async throws -> StoredTranscript
}

struct TranscriptDirectoryContents: Sendable {
    let folders: [Folder]
    let transcripts: [StoredTranscript]
}
