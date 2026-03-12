import Accelerate
@preconcurrency import AVFoundation
import os
import Speech

private let logger = Logger(subsystem: "com.maxime.maurice", category: "SpeechAnalyzer")

final class SpeechAnalyzerLiveTranscription: LiveTranscriptionService, @unchecked Sendable {
    private let locale: Locale

    private var analyzer: SpeechAnalyzer?
    private var transcriber: SpeechTranscriber?
    private var inputContinuation: AsyncStream<AnalyzerInput>.Continuation?
    private var audioEngine: AVAudioEngine?
    private var startTime: Date?
    private var activity: NSObjectProtocol?

    var onAudioLevel: (@Sendable (Float) -> Void)?

    init(locale: Locale = Locale(identifier: "fr-FR")) {
        self.locale = locale
    }

    func prepare(onStateChange: @escaping @Sendable (PreparationState) -> Void) async throws {
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
            throw SpeechAnalyzerError.notPrepared
        }

        let modules: [any SpeechModule] = [transcriber]

        guard let analyzerFormat = await SpeechAnalyzer.bestAvailableAudioFormat(compatibleWith: modules) else {
            throw SpeechAnalyzerError.audioFormatError
        }

        let (inputStream, inputContinuation) = AsyncStream<AnalyzerInput>.makeStream()
        self.inputContinuation = inputContinuation

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
            throw SpeechAnalyzerError.notPrepared
        }

        let modules: [any SpeechModule] = [transcriber]

        guard let analyzerFormat = await SpeechAnalyzer.bestAvailableAudioFormat(compatibleWith: modules) else {
            throw SpeechAnalyzerError.audioFormatError
        }

        let (inputStream, inputContinuation) = AsyncStream<AnalyzerInput>.makeStream()
        self.inputContinuation = inputContinuation

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

        inputContinuation?.finish()
        inputContinuation = nil

        try? await analyzer?.finalizeAndFinishThroughEndOfInput()
        analyzer = nil
        startTime = nil
        activity = nil
        onAudioLevel = nil
    }

    // MARK: - Audio Capture

    private func startFileCapture(fileURL: URL, analyzerFormat: AVAudioFormat) throws {
        guard let audioFile = try? AVAudioFile(forReading: fileURL) else {
            throw SpeechAnalyzerError.fileReadError
        }

        let fileFormat = audioFile.processingFormat
        guard let converter = AVAudioConverter(from: fileFormat, to: analyzerFormat) else {
            throw SpeechAnalyzerError.audioFormatError
        }

        let readBufferSize: AVAudioFrameCount = 1024
        let ratio = analyzerFormat.sampleRate / fileFormat.sampleRate
        let estimatedFrames = AVAudioFrameCount(Double(readBufferSize) * ratio) + 1

        Task.detached { [weak self] in
            guard let self else { return }

            while audioFile.framePosition < audioFile.length {
                guard let readBuffer = AVAudioPCMBuffer(
                    pcmFormat: fileFormat,
                    frameCapacity: readBufferSize
                ) else { break }

                do {
                    try audioFile.read(into: readBuffer)
                } catch {
                    break
                }

                // Compute RMS for visualization (boost for synthetic voice)
                let frameLength = vDSP_Length(readBuffer.frameLength)
                if frameLength > 0, let channelData = readBuffer.floatChannelData {
                    var rms: Float = 0
                    vDSP_rmsqv(channelData[0], 1, &rms, frameLength)
                    self.onAudioLevel?(min(rms * 4, 1.0))
                }

                guard let continuation = self.inputContinuation else { break }

                guard let convertedBuffer = AVAudioPCMBuffer(
                    pcmFormat: analyzerFormat,
                    frameCapacity: estimatedFrames
                ) else { break }

                var error: NSError?
                nonisolated(unsafe) let unsafeReadBuffer = readBuffer
                converter.convert(to: convertedBuffer, error: &error) { _, outStatus in
                    outStatus.pointee = .haveData
                    return unsafeReadBuffer
                }
                guard error == nil, convertedBuffer.frameLength > 0 else { continue }
                continuation.yield(AnalyzerInput(buffer: convertedBuffer))

                // Simulate real-time playback pace
                let chunkDuration = Double(readBuffer.frameLength) / fileFormat.sampleRate
                try? await Task.sleep(for: .milliseconds(Int(chunkDuration * 1000)))
            }

            // Signal end of file: finalize the analyzer so transcriber.results ends
            self.inputContinuation?.finish()
            self.inputContinuation = nil
            try? await self.analyzer?.finalizeAndFinishThroughEndOfInput()
        }
    }

    private func startAudioCapture(analyzerFormat: AVAudioFormat) throws {
        let engine = AVAudioEngine()
        self.audioEngine = engine

        let inputNode = engine.inputNode
        let nativeFormat = inputNode.outputFormat(forBus: 0)

        guard let converter = AVAudioConverter(from: nativeFormat, to: analyzerFormat) else {
            throw SpeechAnalyzerError.audioFormatError
        }

        inputNode.installTap(onBus: 0, bufferSize: 4096, format: nativeFormat) { [weak self] pcmBuffer, _ in
            guard let self else { return }

            // Compute RMS audio level from the raw buffer
            let frameLength = vDSP_Length(pcmBuffer.frameLength)
            if frameLength > 0, let channelData = pcmBuffer.floatChannelData {
                var rms: Float = 0
                vDSP_rmsqv(channelData[0], 1, &rms, frameLength)
                self.onAudioLevel?(rms)
            }

            // Forward audio to speech analyzer
            guard let continuation = self.inputContinuation else { return }

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

enum SpeechAnalyzerError: Error, LocalizedError {
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
