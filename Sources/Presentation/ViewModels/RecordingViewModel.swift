import Foundation

@Observable
@MainActor
final class RecordingViewModel {
    private let recordingUseCase: RecordingUseCase

    private(set) var entries: [TranscriptionEntry] = []
    private(set) var volatileText: String = ""
    private(set) var isRecording = false
    private(set) var preparationState: SpeechModelState = .idle
    private(set) var errorMessage: String?

    var subdirectory: String?

    let audioLevelBuffer = AudioLevelBuffer()

    private var transcription: Transcription?
    private var liveFileURL: URL?
    private var listeningTask: Task<Void, Never>?

    var finalText: String {
        Self.addLineBreaks(entries.map(\.text).joined(separator: " "))
    }

    var formattedVolatileText: String {
        Self.addLineBreaks(volatileText)
    }

    private static func addLineBreaks(_ text: String) -> String {
        text.replacingOccurrences(of: ". ", with: ".\n")
            .replacingOccurrences(of: "? ", with: "?\n")
            .replacingOccurrences(of: "! ", with: "!\n")
    }

    var isPreparing: Bool {
        switch preparationState {
        case .downloading, .loading: true
        default: false
        }
    }

    init(recordingUseCase: RecordingUseCase) {
        self.recordingUseCase = recordingUseCase
    }

    func toggleRecording() {
        if isRecording {
            stopRecording()
        } else {
            startRecording()
        }
    }

    // MARK: - Recording

    private func startRecording() {
        launchPipeline { useCase in
            try await useCase.startRecording()
        }
    }

    private func launchPipeline(
        streamProvider: @escaping @Sendable (RecordingUseCase) async throws -> AsyncStream<TranscriptionEvent>
    ) {
        preparationState = .idle
        errorMessage = nil

        let useCase = recordingUseCase
        let buffer = audioLevelBuffer
        let subdirectory = subdirectory

        listeningTask = Task {
            do {
                // Prepare model on background thread
                try await Task.detached {
                    try await useCase.prepare { [weak self] state in
                        Task { @MainActor in
                            self?.preparationState = state
                        }
                    }

                    useCase.onAudioLevel = { level in
                        buffer.append(level)
                    }
                }.value

                let stream = try await streamProvider(useCase)
                try await processStream(stream, useCase: useCase, subdirectory: subdirectory)
            } catch {
                IssueLogger.log(.error, "Recording failed", error: error)
                let useCase = useCase
                Task.detached { await useCase.stopRecording() }
                errorMessage = error.localizedDescription
                preparationState = .failed(error.localizedDescription)
            }
        }
    }

    private func processStream(
        _ stream: AsyncStream<TranscriptionEvent>,
        useCase: RecordingUseCase,
        subdirectory: String?
    ) async throws {
        entries = []
        volatileText = ""
        audioLevelBuffer.reset()
        transcription = Transcription()
        liveFileURL = try useCase.beginLiveSession(
            startDate: transcription!.startDate,
            subdirectory: subdirectory
        )
        isRecording = true

        for await event in stream {
            switch event {
            case .entry(let entry):
                entries.append(entry)
                transcription?.entries.append(entry)
                volatileText = ""
                if let url = liveFileURL {
                    let useCase = useCase
                    Task.detached { [weak self] in
                        do {
                            try useCase.appendEntry(entry, to: url)
                        } catch {
                            IssueLogger.log(.error, "Failed to append transcript entry", error: error)
                            Task { @MainActor [weak self] in
                                self?.errorMessage = String(localized: "Write error: \(error.localizedDescription)")
                            }
                        }
                    }
                }
            case .volatile(let text):
                volatileText = text
                try? await Task.sleep(for: .milliseconds(30))
            case .error(let message):
                errorMessage = message
            }
        }
        stopRecording()
    }

    private func stopRecording() {
        listeningTask?.cancel()
        listeningTask = nil
        isRecording = false
        volatileText = ""
        audioLevelBuffer.reset()
        transcription = nil
        liveFileURL = nil

        let useCase = recordingUseCase
        Task.detached {
            await useCase.stopRecording()
        }
    }
}
