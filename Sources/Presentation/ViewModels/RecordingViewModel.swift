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

    private func startRecording(fromFileURL fileURL: URL) {
        Task {
            preparationState = .idle
            errorMessage = nil

            do {
                try await recordingUseCase.prepare { [weak self] state in
                    Task { @MainActor in
                        self?.preparationState = state
                    }
                }

                let buffer = audioLevelBuffer
                recordingUseCase.onAudioLevel = { level in
                    buffer.append(level)
                }

                let stream = try await recordingUseCase.startRecording(fromFileURL: fileURL)
                entries = []
                volatileText = ""
                audioLevelBuffer.reset()
                transcription = Transcription()
                liveFileURL = try recordingUseCase.beginLiveSession(startDate: transcription!.startDate, subdirectory: subdirectory)
                isRecording = true

                listeningTask = Task {
                    for await event in stream {
                        switch event {
                        case .entry(let entry):
                            entries.append(entry)
                            transcription?.entries.append(entry)
                            volatileText = ""
                            if let url = liveFileURL {
                                try? recordingUseCase.appendEntry(entry, to: url)
                            }
                        case .volatile(let text):
                            volatileText = text
                            try? await Task.sleep(for: .milliseconds(30))
                        case .error(let message):
                            errorMessage = message
                        }
                    }
                    // File playback finished — auto-stop
                    stopRecording()
                }
            } catch {
                await recordingUseCase.stopRecording()
                errorMessage = error.localizedDescription
                preparationState = .failed(error.localizedDescription)
            }
        }
    }

    private func startRecording() {
        Task {
            preparationState = .idle
            errorMessage = nil

            do {
                try await recordingUseCase.prepare { [weak self] state in
                    Task { @MainActor in
                        self?.preparationState = state
                    }
                }

                let buffer = audioLevelBuffer
                recordingUseCase.onAudioLevel = { level in
                    buffer.append(level)
                }

                let stream = try await recordingUseCase.startRecording()
                entries = []
                volatileText = ""
                audioLevelBuffer.reset()
                transcription = Transcription()
                liveFileURL = try recordingUseCase.beginLiveSession(startDate: transcription!.startDate, subdirectory: subdirectory)
                isRecording = true

                listeningTask = Task {
                    for await event in stream {
                        switch event {
                        case .entry(let entry):
                            entries.append(entry)
                            transcription?.entries.append(entry)
                            volatileText = ""
                            if let url = liveFileURL {
                                try? recordingUseCase.appendEntry(entry, to: url)
                            }
                        case .volatile(let text):
                            volatileText = text
                            try? await Task.sleep(for: .milliseconds(30))
                        case .error(let message):
                            errorMessage = message
                        }
                    }
                }
            } catch {
                await recordingUseCase.stopRecording()
                errorMessage = error.localizedDescription
                preparationState = .failed(error.localizedDescription)
            }
        }
    }

    private func stopRecording() {
        Task {
            await recordingUseCase.stopRecording()

            listeningTask?.cancel()
            listeningTask = nil
            isRecording = false
            volatileText = ""
            audioLevelBuffer.reset()
            transcription = nil
            liveFileURL = nil
        }
    }
}
