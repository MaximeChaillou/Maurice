import Foundation

final class RecordingUseCase: Sendable {
    private let transcription: LiveTranscriptionService
    let storage: TranscriptionStorage

    init(transcription: LiveTranscriptionService, storage: TranscriptionStorage) {
        self.transcription = transcription
        self.storage = storage
    }

    func prepare(onStateChange: @escaping @Sendable (SpeechModelState) -> Void) async throws {
        try await transcription.prepare(onStateChange: onStateChange)
    }

    var onAudioLevel: (@Sendable (Float) -> Void)? {
        get { transcription.onAudioLevel }
        set { transcription.onAudioLevel = newValue }
    }

    func startRecording() async throws -> AsyncStream<TranscriptionEvent> {
        try await transcription.startTranscription()
    }

    func startRecording(fromFileURL fileURL: URL) async throws -> AsyncStream<TranscriptionEvent> {
        try await transcription.startTranscription(fromFileURL: fileURL)
    }

    func beginLiveSession(startDate: Date, subdirectory: String? = nil) throws -> URL {
        try storage.beginLiveSession(startDate: startDate, subdirectory: subdirectory)
    }

    func appendEntry(_ entry: TranscriptionEntry, to fileURL: URL) throws {
        try storage.appendEntry(entry, to: fileURL)
    }

    func stopRecording() async {
        await transcription.stopTranscription()
    }
}
