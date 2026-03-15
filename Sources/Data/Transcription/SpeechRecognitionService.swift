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

    init(locale: Locale = Locale(identifier: "fr-FR")) {
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
            options: [.userInitiated, .idleSystemSleepDisabled],
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
                    continuation.yield(.error(error.localizedDescription))
                }
                continuation.finish()
            }
        }
    }

    func startTranscription(fromFileURL fileURL: URL) async throws -> AsyncStream<TranscriptionEvent> {
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

        activity = ProcessInfo.processInfo.beginActivity(
            options: [.userInitiated, .idleSystemSleepDisabled],
            reason: "Debug file transcription"
        )

        try startFileCapture(fileURL: fileURL, analyzerFormat: analyzerFormat)

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

    private struct FileCaptureContext {
        let audioFile: AVAudioFile
        let converter: AVAudioConverter
        let readBufferSize: AVAudioFrameCount
        let estimatedFrames: AVAudioFrameCount
        let fileFormat: AVAudioFormat
        let analyzerFormat: AVAudioFormat
    }

    private func startFileCapture(fileURL: URL, analyzerFormat: AVAudioFormat) throws {
        guard let audioFile = try? AVAudioFile(forReading: fileURL) else {
            throw SpeechRecognitionError.fileReadError
        }

        let fileFormat = audioFile.processingFormat
        guard let converter = AVAudioConverter(from: fileFormat, to: analyzerFormat) else {
            throw SpeechRecognitionError.audioFormatError
        }

        let readBufferSize: AVAudioFrameCount = 1024
        let ratio = analyzerFormat.sampleRate / fileFormat.sampleRate
        let ctx = FileCaptureContext(
            audioFile: audioFile,
            converter: converter,
            readBufferSize: readBufferSize,
            estimatedFrames: AVAudioFrameCount(Double(readBufferSize) * ratio) + 1,
            fileFormat: fileFormat,
            analyzerFormat: analyzerFormat
        )

        Task.detached { [weak self] in
            guard let self else { return }

            while audioFile.framePosition < audioFile.length {
                guard self.processNextFileChunk(ctx) else { break }
                let chunkDuration = Double(readBufferSize) / fileFormat.sampleRate
                try? await Task.sleep(for: .milliseconds(Int(chunkDuration * 1000)))
            }

            self.lock.withLock {
                self.inputContinuation?.finish()
                self.inputContinuation = nil
            }
            try? await self.analyzer?.finalizeAndFinishThroughEndOfInput()
        }
    }

    /// Process a single chunk from the audio file. Returns `false` to stop the loop.
    private func processNextFileChunk(_ ctx: FileCaptureContext) -> Bool {
        guard let readBuffer = AVAudioPCMBuffer(
            pcmFormat: ctx.fileFormat,
            frameCapacity: ctx.readBufferSize
        ) else { return false }

        do {
            try ctx.audioFile.read(into: readBuffer)
        } catch {
            return false
        }

        let frameLength = vDSP_Length(readBuffer.frameLength)
        if frameLength > 0, let channelData = readBuffer.floatChannelData {
            var rms: Float = 0
            vDSP_rmsqv(channelData[0], 1, &rms, frameLength)
            let handler = lock.withLock { onAudioLevelHandler }
            handler?(min(rms * 4, 1.0))
        }

        let continuation = lock.withLock { inputContinuation }
        guard let continuation else { return false }

        guard let convertedBuffer = AVAudioPCMBuffer(
            pcmFormat: ctx.analyzerFormat,
            frameCapacity: ctx.estimatedFrames
        ) else { return false }

        var error: NSError?
        nonisolated(unsafe) let unsafeReadBuffer = readBuffer
        ctx.converter.convert(to: convertedBuffer, error: &error) { _, outStatus in
            outStatus.pointee = .haveData
            return unsafeReadBuffer
        }
        guard error == nil, convertedBuffer.frameLength > 0 else { return true }
        continuation.yield(AnalyzerInput(buffer: convertedBuffer))
        return true
    }

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
    case fileReadError

    var errorDescription: String? {
        switch self {
        case .notPrepared: "SpeechAnalyzer is not prepared. Call prepare() first."
        case .audioFormatError: "Failed to create audio format for SpeechAnalyzer."
        case .fileReadError: "Failed to read audio file."
        }
    }
}
