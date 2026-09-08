import CVieNeuNanoRuntime
import Domain
import Foundation
import Utility

private enum VieNeuNanoSynthesisError: Error {
    case initializationFailed(String)
    case synthesisFailed(String)
    case emptyAudio
}

private final class NanoCancellation: @unchecked Sendable {
    let handle: OpaquePointer

    init() throws {
        guard let handle = letter_nano_cancellation_create() else {
            throw VieNeuNanoSynthesisError.initializationFailed("Unable to allocate cancellation token")
        }
        self.handle = handle
    }

    deinit { letter_nano_cancellation_destroy(handle) }

    func request() { letter_nano_cancellation_request(handle) }

    func check() throws {
        if letter_nano_cancellation_is_requested(handle) == 1 { throw CancellationError() }
    }
}

/// Adapts the native Nano engine to the same bounded-prefetch playback path as
/// other non-streaming models. Mutable engine state is confined to `queue`.
public final class VieNeuNanoSpeechSynthesizer: LocalSpeechSynthesizing, @unchecked Sendable {
    private static let samplingSteps: Int32 = 8

    private let models: BundledVieNeuNanoModels
    private let selectedVoice: @Sendable () -> OfflineSpeechVoice
    private let queue = DispatchQueue(label: "com.letter.vieneu-nano-synthesis", qos: .userInitiated)
    private var engine: OpaquePointer?

    public init(
        models: BundledVieNeuNanoModels,
        selectedVoice: @escaping @Sendable () -> OfflineSpeechVoice = { .adam }
    ) {
        self.models = models
        self.selectedVoice = selectedVoice
    }

    deinit {
        if let engine { letter_nano_destroy(engine) }
    }

    public func prepare(for languageCode: String) async throws {
        try await withCheckedThrowingContinuation { continuation in
            queue.async { [self] in
                do {
                    _ = try loadedEngine()
                    continuation.resume()
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    public func chunkingOptions(for languageCode: String) -> LocalSpeechChunkingOptions {
        // The shared chunker may append a tail shorter than 20 UTF-16 units.
        // Leave room under Nano's 140-scalar limit and normalize to NFC below.
        LocalSpeechChunkingOptions(
            maximumLength: 120, lineBreakBehavior: .whitespace, prefetchChunkCount: 2
        )
    }

    public func synthesize(_ request: LocalSpeechSynthesisRequest) async throws -> SynthesizedSpeechAudio {
        let cancellation = try NanoCancellation()
        return try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { continuation in
                queue.async { [self] in
                    do {
                        try cancellation.check()
                        let engine = try loadedEngine()
                        try cancellation.check()
                        continuation.resume(returning: try generate(request, engine: engine, cancellation: cancellation))
                    } catch {
                        continuation.resume(throwing: error)
                    }
                }
            }
        } onCancel: {
            cancellation.request()
        }
    }

    private func loadedEngine() throws -> OpaquePointer {
        if let engine { return engine }
        let created = models.modelDirectory.path.withCString { directory in
            models.g2pDictionary.path.withCString { dictionary in
                letter_nano_create(directory, dictionary, 1)
            }
        }
        guard let created else {
            throw VieNeuNanoSynthesisError.initializationFailed("Unable to allocate Nano engine")
        }
        guard letter_nano_is_ready(created) == 1 else {
            let message = String(cString: letter_nano_last_error(created))
            letter_nano_destroy(created)
            throw VieNeuNanoSynthesisError.initializationFailed(message)
        }
        engine = created
        return created
    }

    private func generate(
        _ request: LocalSpeechSynthesisRequest,
        engine: OpaquePointer,
        cancellation: NanoCancellation
    ) throws -> SynthesizedSpeechAudio {
        let text = request.text.precomposedStringWithCanonicalMapping
            .split(whereSeparator: \.isWhitespace).joined(separator: " ")
        let selected = selectedVoice()
        let voice = OfflineSpeechModel.vieNeuV3Nano.availableVoices.contains(selected) ? selected : .adam
        var audio = letter_nano_audio()
        defer { letter_nano_audio_free(&audio) }
#if DEBUG
        let start = DispatchTime.now().uptimeNanoseconds
        let resources = ProcessResourceSnapshot.capture()
#endif
        let status = text.withCString { text in
            voice.rawValue.withCString { voice in
                letter_nano_synthesize(engine, text, voice, Self.samplingSteps, UInt32.random(in: .min ... .max), cancellation.handle, &audio)
            }
        }
        try cancellation.check()
        guard status == 0 else {
            throw VieNeuNanoSynthesisError.synthesisFailed(String(cString: letter_nano_last_error(engine)))
        }
        guard let samples = audio.samples, audio.sample_count > 0, audio.sample_rate == 24_000 else {
            throw VieNeuNanoSynthesisError.emptyAudio
        }
#if DEBUG
        reportSynthesis(start: start, resources: resources, sampleCount: audio.sample_count, rate: request.rateMultiplier)
#endif
        return SynthesizedSpeechAudio(
            data: WaveEncoder.encode(
                samples: Array(UnsafeBufferPointer(start: samples, count: audio.sample_count)),
                sampleRate: Int(audio.sample_rate)
            ),
            playbackRate: Float(min(max(request.rateMultiplier, 0.5), 3))
        )
    }

#if DEBUG
    private func reportSynthesis(start: UInt64, resources: ProcessResourceSnapshot, sampleCount: Int, rate: Double) {
        let elapsed = Double(DispatchTime.now().uptimeNanoseconds - start) / 1_000_000_000
        let duration = Double(sampleCount) / 24_000
        let summary = ProcessResourceSnapshot.capture().summary(since: resources, elapsedSeconds: elapsed)
        logDebug("[Letter][Speech][VieNeuNano] threads=1 steps=\(Self.samplingSteps) " +
            String(format: "audio=%.2fs wall=%.2fs generation=%.2fx playback=%.2fx headroom=%.2fx ",
                   duration, elapsed, duration / max(elapsed, 0.001), rate,
                   duration / max(elapsed, 0.001) / min(max(rate, 0.5), 3)) + summary)
    }
#endif
}
