import Accelerate
@preconcurrency import AVFoundation
import os
import Speech

private let logger = Logger(subsystem: "com.maxime.maurice", category: "SpeechRecognition")

final class SpeechRecognitionService: LiveTranscriptionService, @unchecked Sendable {
    private let locale: Locale

    /// Lock protecting state shared between the audio callback thread and async methods.
    private let lock = NSLock()

    // State accessed from audio callback — always access under `lock`.
    private var inputContinuation: AsyncStream<AnalyzerInput>.Continuation?
    private var onAudioLevelHandler: (@Sendable (Float) -> Void)?

    // State accessed only from async context (effectively serialized by caller).
    private var analyzer: SpeechAnalyzer?
    private var transcriber: SpeechTranscriber?
    private var audioEngine: AVAudioEngine?
    private var startTime: Date?
    private var activity: NSObjectProtocol?

    var onAudioLevel: (@Sendable (Float) -> Void)? {
        get { lock.withLock { onAudioLevelHandler } }
        set { lock.withLock { onAudioLevelHandler = newValue } }
    }

    init(locale: Locale = Locale(identifier: AppSettings.transcriptionLanguage)) {
        self.locale = locale
    }

    func prepare(onStateChange: @escaping @Sendable (SpeechModelState) -> Void) async throws {
        onStateChange(.loading)

        let transcriber = SpeechTranscriber(
            locale: locale,
            preset: .progressiveTranscription
        )
        self.transcriber = transcriber

        // Ensure the on-device model is installed
        let installed = await Set(SpeechTranscriber.installedLocales.map { $0.identifier(.bcp47) })
        if !installed.contains(locale.identifier(.bcp47)) {
            onStateChange(.downloading(progress: 0))
            if let downloader = try await AssetInventory.assetInstallationRequest(supporting: [transcriber]) {
                try await downloader.downloadAndInstall()
            }
        }

        logger.info("SpeechAnalyzer model ready for locale: \(self.locale.identifier)")
        onStateChange(.ready)
    }

    func startTranscription() async throws -> AsyncStream<TranscriptionEvent> {
        guard let transcriber else {
            throw SpeechRecognitionError.notPrepared
        }

        let modules: [any SpeechModule] = [transcriber]

        guard let analyzerFormat = await SpeechAnalyzer.bestAvailableAudioFormat(compatibleWith: modules) else {
            throw SpeechRecognitionError.audioFormatError
        }

        let (inputStream, continuation) = AsyncStream<AnalyzerInput>.makeStream()
        lock.withLock { inputContinuation = continuation }

        let analyzer = SpeechAnalyzer(
            inputSequence: inputStream,
            modules: modules
        )
        self.analyzer = analyzer

        try await analyzer.prepareToAnalyze(in: analyzerFormat)

        // Prevent App Nap from interrupting audio capture
        activity = ProcessInfo.processInfo.beginActivity(
            options: [.userInitiated, .idleSystemSleepDisabled, .idleDisplaySleepDisabled],
            reason: "Recording audio transcription"
        )

        try startAudioCapture(analyzerFormat: analyzerFormat)

        let startTime = Date()
        self.startTime = startTime

        return AsyncStream<TranscriptionEvent> { continuation in
            Task {
                do {
                    for try await result in transcriber.results {
                        let text = String(result.text.characters)
                            .trimmingCharacters(in: .whitespacesAndNewlines)
                        guard !text.isEmpty else { continue }

                        if result.isFinal {
                            let elapsed = Date().timeIntervalSince(startTime)
                            let entry = TranscriptionEntry(text: text, timestamp: elapsed)
                            continuation.yield(.entry(entry))
                        } else {
                            continuation.yield(.volatile(text))
                        }
                    }
                } catch {
                    IssueLogger.log(.error, "Speech recognition stream error", error: error)
                    continuation.yield(.error(error.localizedDescription))
                }
                continuation.finish()
            }
        }
    }

    func stopTranscription() async {
        if let engine = audioEngine {
            engine.inputNode.removeTap(onBus: 0)
            engine.stop()
            audioEngine = nil
        }

        lock.withLock {
            inputContinuation?.finish()
            inputContinuation = nil
            onAudioLevelHandler = nil
        }

        try? await analyzer?.finalizeAndFinishThroughEndOfInput()
        analyzer = nil
        startTime = nil
        activity = nil
    }

    // MARK: - Audio Capture

    private func startAudioCapture(analyzerFormat: AVAudioFormat) throws {
        let engine = AVAudioEngine()
        self.audioEngine = engine

        let inputNode = engine.inputNode
        let nativeFormat = inputNode.outputFormat(forBus: 0)

        guard let converter = AVAudioConverter(from: nativeFormat, to: analyzerFormat) else {
            throw SpeechRecognitionError.audioFormatError
        }

        inputNode.installTap(onBus: 0, bufferSize: 4096, format: nativeFormat) { [weak self] pcmBuffer, _ in
            guard let self else { return }

            // Compute RMS audio level from the raw buffer
            let frameLength = vDSP_Length(pcmBuffer.frameLength)
            if frameLength > 0, let channelData = pcmBuffer.floatChannelData {
                var rms: Float = 0
                vDSP_rmsqv(channelData[0], 1, &rms, frameLength)
                let handler = self.lock.withLock { self.onAudioLevelHandler }
                handler?(rms)
            }

            // Forward audio to speech analyzer
            let continuation = self.lock.withLock { self.inputContinuation }
            guard let continuation else { return }

            let ratio = analyzerFormat.sampleRate / nativeFormat.sampleRate
            let estimatedFrames = AVAudioFrameCount(Double(pcmBuffer.frameLength) * ratio) + 1
            guard let convertedBuffer = AVAudioPCMBuffer(
                pcmFormat: analyzerFormat,
                frameCapacity: estimatedFrames
            ) else { return }

            var error: NSError?
            nonisolated(unsafe) let unsafePcmBuffer = pcmBuffer
            converter.convert(to: convertedBuffer, error: &error) { _, outStatus in
                outStatus.pointee = .haveData
                return unsafePcmBuffer
            }
            guard error == nil, convertedBuffer.frameLength > 0 else { return }
            continuation.yield(AnalyzerInput(buffer: convertedBuffer))
        }

        engine.prepare()
        try engine.start()
    }
}

enum SpeechRecognitionError: Error, LocalizedError {
    case notPrepared
    case audioFormatError

    var errorDescription: String? {
        switch self {
        case .notPrepared: "SpeechAnalyzer is not prepared. Call prepare() first."
        case .audioFormatError: "Failed to create audio format for SpeechAnalyzer."
        }
    }
}
