import Foundation

protocol LiveTranscriptionService: AnyObject, Sendable {
    func prepare(onStateChange: @escaping @Sendable (SpeechModelState) -> Void) async throws
    func startTranscription() async throws -> AsyncStream<TranscriptionEvent>
    func startTranscription(fromFileURL fileURL: URL) async throws -> AsyncStream<TranscriptionEvent>
    func stopTranscription() async
    var onAudioLevel: (@Sendable (Float) -> Void)? { get set }
}
