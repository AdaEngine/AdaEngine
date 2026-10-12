#if os(iOS) || os(visionOS)
import AVFAudio
import Foundation
import Speech

/// Type-erased control surface so dictation can hold an iOS 26 session without
/// availability annotations on its stored properties.
struct MobileEditorAnalyzerHandle {
    /// Called on the audio tap queue; returns the input level in 0...1.
    let append: @Sendable (AVAudioPCMBuffer) -> Float
    let cancel: @MainActor () -> Void
    let finish: @MainActor () async -> Void
}

/// On-device long-form transcription through `SpeechAnalyzer` + `SpeechTranscriber` (iOS/visionOS 26).
@available(iOS 26.0, visionOS 26.0, *)
@MainActor
final class MobileEditorSpeechAnalyzerSession {
    private let analyzer: SpeechAnalyzer
    private let transcriber: SpeechTranscriber
    private let feeder: MobileEditorAnalyzerFeeder
    private let stream: AsyncStream<AnalyzerInput>
    private var resultsTask: Task<Void, Never>?
    private var analysisTask: Task<Void, Never>?

    private init(analyzer: SpeechAnalyzer, transcriber: SpeechTranscriber, format: AVAudioFormat) {
        self.analyzer = analyzer
        self.transcriber = transcriber
        let (stream, continuation) = AsyncStream<AnalyzerInput>.makeStream(bufferingPolicy: .unbounded)
        self.stream = stream
        self.feeder = MobileEditorAnalyzerFeeder(targetFormat: format, continuation: continuation)
    }

    /// Returns nil when the locale has no on-device model, so callers can fall back to `SFSpeechRecognizer`.
    /// `onModelDownload` fires once when the language model must be fetched first.
    static func prepare(
        locale: Locale,
        onModelDownload: @MainActor () -> Void
    ) async throws -> MobileEditorSpeechAnalyzerSession? {
        guard SpeechTranscriber.isAvailable,
              let supported = await SpeechTranscriber.supportedLocale(equivalentTo: locale) else {
            return nil
        }
        let transcriber = SpeechTranscriber(locale: supported, preset: .progressiveTranscription)
        if let request = try await AssetInventory.assetInstallationRequest(supporting: [transcriber]) {
            onModelDownload()
            try await request.downloadAndInstall()
        }
        guard let format = await SpeechAnalyzer.bestAvailableAudioFormat(compatibleWith: [transcriber]) else {
            return nil
        }
        return MobileEditorSpeechAnalyzerSession(
            analyzer: SpeechAnalyzer(modules: [transcriber]),
            transcriber: transcriber,
            format: format
        )
    }

    func start(
        onText: @escaping @MainActor (String) -> Void,
        onFailure: @escaping @MainActor (String) -> Void
    ) -> MobileEditorAnalyzerHandle {
        let transcriber = transcriber
        resultsTask = Task { @MainActor in
            var accumulator = MobileEditorTranscriptAccumulator()
            do {
                for try await result in transcriber.results {
                    let text = accumulator.apply(String(result.text.characters), isFinal: result.isFinal)
                    onText(text)
                }
            } catch is CancellationError {
            } catch {
                onFailure(error.localizedDescription)
            }
        }
        let analyzer = analyzer
        let stream = stream
        analysisTask = Task { @MainActor in
            do {
                try await analyzer.start(inputSequence: stream)
            } catch is CancellationError {
            } catch {
                onFailure(error.localizedDescription)
            }
        }
        return MobileEditorAnalyzerHandle(
            append: { [feeder] in feeder.append($0) },
            cancel: { [weak self] in self?.cancel() },
            finish: { [weak self] in await self?.finish() }
        )
    }

    /// Flushes buffered audio so the last words arrive as a final result.
    private func finish() async {
        feeder.finish()
        try? await analyzer.finalizeAndFinishThroughEndOfInput()
        await resultsTask?.value
    }

    private func cancel() {
        feeder.finish()
        resultsTask?.cancel()
        analysisTask?.cancel()
        let analyzer = analyzer
        Task { await analyzer.cancelAndFinishNow() }
    }
}

/// Hands one buffer to `AVAudioConverter`'s input block exactly once.
private final class MobileEditorOneShotBuffer: @unchecked Sendable {
    private var buffer: AVAudioPCMBuffer?

    init(_ buffer: AVAudioPCMBuffer) {
        self.buffer = buffer
    }

    func take() -> AVAudioPCMBuffer? {
        defer { buffer = nil }
        return buffer
    }
}

/// Runs on the audio tap queue: converts to the analyzer's format and measures level.
/// The converter is only touched from that queue; `finish` is thread-safe.
@available(iOS 26.0, visionOS 26.0, *)
final class MobileEditorAnalyzerFeeder: @unchecked Sendable {
    private let targetFormat: AVAudioFormat
    private let continuation: AsyncStream<AnalyzerInput>.Continuation
    private var converter: AVAudioConverter?

    init(targetFormat: AVAudioFormat, continuation: AsyncStream<AnalyzerInput>.Continuation) {
        self.targetFormat = targetFormat
        self.continuation = continuation
    }

    func append(_ buffer: AVAudioPCMBuffer) -> Float {
        let level = Self.level(of: buffer)
        if let converted = convert(buffer) {
            continuation.yield(AnalyzerInput(buffer: converted))
        }
        return level
    }

    func finish() {
        continuation.finish()
    }

    private func convert(_ buffer: AVAudioPCMBuffer) -> AVAudioPCMBuffer? {
        if buffer.format == targetFormat {
            return buffer
        }
        if converter == nil || converter?.inputFormat != buffer.format {
            converter = AVAudioConverter(from: buffer.format, to: targetFormat)
        }
        guard let converter else {
            return nil
        }
        let ratio = targetFormat.sampleRate / buffer.format.sampleRate
        let capacity = AVAudioFrameCount((Double(buffer.frameLength) * ratio).rounded(.up)) + 64
        guard let output = AVAudioPCMBuffer(pcmFormat: targetFormat, frameCapacity: capacity) else {
            return nil
        }
        let source = MobileEditorOneShotBuffer(buffer)
        var error: NSError?
        let status = converter.convert(to: output, error: &error) { _, inputStatus in
            guard let next = source.take() else {
                inputStatus.pointee = .noDataNow
                return nil
            }
            inputStatus.pointee = .haveData
            return next
        }
        guard status != .error, error == nil, output.frameLength > 0 else {
            return nil
        }
        return output
    }

    private static func level(of buffer: AVAudioPCMBuffer) -> Float {
        // AVAudioEngine keeps this channel memory alive for the tap callback.
        guard let samples = unsafe buffer.floatChannelData?[0], buffer.frameLength > 0 else {
            return 0
        }
        var sum: Float = 0
        for index in 0..<Int(buffer.frameLength) { sum += unsafe samples[index] * samples[index] }
        let rms = sqrt(sum / Float(buffer.frameLength))
        return rms.isFinite ? min(max(rms * 8, 0), 1) : 0
    }
}
#endif
