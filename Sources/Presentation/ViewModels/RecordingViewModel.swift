import Foundation

@Observable
@MainActor
final class RecordingViewModel {
    private let recordingUseCase: RecordingUseCase

    private(set) var entries: [TranscriptionEntry] = []
    private(set) var volatileText: String = ""
    private(set) var isRecording = false
    private(set) var preparationState: PreparationState = .idle
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

    func simulateFromFile() {
        guard !isRecording else { return }
        guard let url = Bundle.main.url(forResource: "debug_sample", withExtension: "aiff") else {
            errorMessage = "Fichier audio debug introuvable dans le bundle."
            return
        }
        startRecording(fromFileURL: url)
    }

    // MARK: - Recording

    private func startRecording(fromFileURL fileURL: URL) {
        launchPipeline { useCase in
            try await useCase.startRecording(fromFileURL: fileURL)
        }
    }

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

                entries = []
                volatileText = ""
                audioLevelBuffer.reset()
                transcription = Transcription()
                liveFileURL = try useCase.beginLiveSession(
                    startDate: transcription!.startDate,
                    subdirectory: subdirectory
                )
                isRecording = true

                // Stream loop stays on MainActor for smooth UI
                for await event in stream {
                    switch event {
                    case .entry(let entry):
                        entries.append(entry)
                        transcription?.entries.append(entry)
                        volatileText = ""
                        // File I/O on background
                        if let url = liveFileURL {
                            let useCase = useCase
                            Task.detached {
                                try? useCase.appendEntry(entry, to: url)
                            }
                        }
                    case .volatile(let text):
                        volatileText = text
                        try? await Task.sleep(for: .milliseconds(30))
                    case .error(let message):
                        errorMessage = message
                    }
                }
                // Stream ended (file playback) — auto-stop
                stopRecording()
            } catch {
                let useCase = useCase
                Task.detached { await useCase.stopRecording() }
                errorMessage = error.localizedDescription
                preparationState = .failed(error.localizedDescription)
            }
        }
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
