import CVieNeuRuntime
import Domain
import Foundation
import Utility

private enum VieNeuSpeechSynthesisError: Error {
    case initializationFailed(String)
    case synthesisFailed(String)
    case emptyAudio
}

private final class VieNeuSynthesisCancellation: @unchecked Sendable {
    let nativeHandle: OpaquePointer

    init?() {
        guard let nativeHandle = letter_vieneu_cancellation_create() else {
            return nil
        }
        self.nativeHandle = nativeHandle
    }

    deinit {
        letter_vieneu_cancellation_destroy(nativeHandle)
    }

    var isRequested: Bool {
        letter_vieneu_cancellation_is_requested(nativeHandle) == 1
    }

    func request() {
        letter_vieneu_cancellation_request(nativeHandle)
    }
}

private final class VieNeuPCMStreamContext: @unchecked Sendable {
    let continuation: AsyncThrowingStream<
        SynthesizedSpeechPCMChunk,
        Error
    >.Continuation
    let playbackRate: Float
    private(set) var callbackCount = 0
    private(set) var sampleCount = 0
    private(set) var sampleRate = 0

    init(
        continuation: AsyncThrowingStream<
            SynthesizedSpeechPCMChunk,
            Error
        >.Continuation,
        playbackRate: Float
    ) {
        self.continuation = continuation
        self.playbackRate = playbackRate
    }

    func record(sampleCount: Int, sampleRate: Int) {
        callbackCount += 1
        self.sampleCount += sampleCount
        self.sampleRate = sampleRate
    }

    var audioDuration: TimeInterval {
        guard sampleRate > 0 else { return 0 }
        return TimeInterval(sampleCount) / TimeInterval(sampleRate)
    }
}

private func receiveVieNeuPCMChunk(
    _ samples: UnsafePointer<Float>?,
    _ sampleCount: Int,
    _ sampleRate: Int32,
    _ rawContext: UnsafeMutableRawPointer?
) -> Int32 {
    guard let samples,
          sampleCount > 0,
          sampleRate > 0,
          let rawContext else { return 1 }
    let context = Unmanaged<VieNeuPCMStreamContext>
        .fromOpaque(rawContext)
        .takeUnretainedValue()
    context.record(sampleCount: sampleCount, sampleRate: Int(sampleRate))
    let result = context.continuation.yield(
        SynthesizedSpeechPCMChunk(
            samples: Array(UnsafeBufferPointer(start: samples, count: sampleCount)),
            sampleRate: Int(sampleRate),
            playbackRate: context.playbackRate
        )
    )
    if case .terminated = result {
        return 1
    }
    return 0
}

public final class VieNeuSpeechSynthesizer: LocalSpeechSynthesizing, @unchecked Sendable {
    private struct EngineConfiguration: Equatable {
        let threadCount: Int32
        let quantizerCount: Int32
    }

    private static let sustainableThreadCount: Int32 = 1
    private static let highRateThreadCount: Int32 = 2
    private static let highRateThreshold: Float = 2.5
    private static let fullQuantizerCount: Int32 = 16
    private static let highRateQuantizerCount: Int32 = 8

    private let models: BundledVieNeuModels
    private let selectedVoice: @Sendable () -> OfflineSpeechVoice
    private let queue = DispatchQueue(
        label: "com.letter.vieneu-speech-synthesis",
        qos: .userInitiated
    )
    private var engine: OpaquePointer?
    private var engineConfiguration: EngineConfiguration?

    public init(
        models: BundledVieNeuModels,
        selectedVoice: @escaping @Sendable () -> OfflineSpeechVoice = { .ngocLinh }
    ) {
        self.models = models
        self.selectedVoice = selectedVoice
    }

    public func prepare(for languageCode: String) async throws {
        try await withCheckedThrowingContinuation { continuation in
            queue.async { [self] in
                do {
                    _ = try loadedEngine(
                        Self.engineConfiguration(for: 3)
                    )
                    continuation.resume()
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    deinit {
        destroyLoadedEngine()
    }

    public func chunkingOptions(
        for languageCode: String
    ) -> LocalSpeechChunkingOptions {
        LocalSpeechChunkingOptions(
            maximumLength: 220,
            lineBreakBehavior: .whitespace,
            sentenceBoundaryPause: 0.18,
            minorBoundaryPause: 0.04
        )
    }

    public func supportsPCMStreaming(for languageCode: String) -> Bool { true }

    public func synthesizePCMStream(
        _ request: LocalSpeechSynthesisRequest
    ) -> AsyncThrowingStream<SynthesizedSpeechPCMChunk, Error> {
        AsyncThrowingStream { continuation in
            guard let cancellation = VieNeuSynthesisCancellation() else {
                continuation.finish(
                    throwing: VieNeuSpeechSynthesisError.initializationFailed(
                        "Unable to allocate a VieNeu cancellation token."
                    )
                )
                return
            }
            let playbackRate = Self.playbackRate(for: request.rateMultiplier)
            let engineConfiguration = Self.engineConfiguration(
                for: playbackRate
            )
            let context = VieNeuPCMStreamContext(
                continuation: continuation,
                playbackRate: playbackRate
            )
            continuation.onTermination = { @Sendable _ in
                cancellation.request()
            }
            queue.async { [self] in
                guard !cancellation.isRequested else {
                    continuation.finish(throwing: CancellationError())
                    return
                }
                do {
                    let engine = try loadedEngine(engineConfiguration)
                    guard !cancellation.isRequested else {
                        throw CancellationError()
                    }
                    var options = letter_vieneu_default_synthesis_options()
                    options.maximum_frames = 260
                    options.maximum_characters = 224
                    options.playback_rate = playbackRate
                    let synthesisText = normalizedWhitespace(in: request.text)
                    let voiceID = selectedVoice().rawValue
#if DEBUG
                    let synthesisStart = DispatchTime.now().uptimeNanoseconds
                    let resourceStart = ProcessResourceSnapshot.capture()
#endif
                    let result = synthesisText.withCString { text in
                        options.text = text
                        return voiceID.withCString { voice in
                            options.voice_id = voice
                            return letter_vieneu_synthesize_stream(
                                engine,
                                &options,
                                cancellation.nativeHandle,
                                receiveVieNeuPCMChunk,
                                Unmanaged.passUnretained(context).toOpaque()
                            )
                        }
                    }
                    guard result == 0 else {
                        if cancellation.isRequested {
                            throw CancellationError()
                        }
                        throw VieNeuSpeechSynthesisError.synthesisFailed(
                            String(cString: letter_vieneu_last_error(engine))
                        )
                    }
#if DEBUG
                    let synthesisEnd = DispatchTime.now().uptimeNanoseconds
                    let elapsedSeconds = TimeInterval(
                        synthesisEnd - synthesisStart
                    ) / 1_000_000_000
                    let generationRate = elapsedSeconds > 0
                        ? context.audioDuration / elapsedSeconds
                        : 0
                    let resources = ProcessResourceSnapshot.capture()
                        .summary(
                            since: resourceStart,
                            elapsedSeconds: elapsedSeconds
                        )
                    logDebug(
                        "[Letter][Speech][VieNeu] streamed chars=\(synthesisText.count) " +
                        String(format: "rate=%.2f ", playbackRate) +
                        "lm_threads=\(engineConfiguration.threadCount) " +
                        "vq=\(engineConfiguration.quantizerCount) " +
                        "acoustic_codec_threads=1 " +
                        String(
                            format: "audio=%.2fs generation=%.2fx callbacks=%d ",
                            context.audioDuration,
                            generationRate,
                            context.callbackCount
                        ) +
                        "wall=\((synthesisEnd - synthesisStart) / 1_000_000)ms " +
                        resources
                    )
#endif
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
        }
    }

    public func synthesize(
        _ request: LocalSpeechSynthesisRequest
    ) async throws -> SynthesizedSpeechAudio {
        guard let cancellation = VieNeuSynthesisCancellation() else {
            throw VieNeuSpeechSynthesisError.initializationFailed(
                "Unable to allocate a VieNeu cancellation token."
            )
        }
        return try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { continuation in
                queue.async { [self] in
                    guard !cancellation.isRequested else {
                        continuation.resume(throwing: CancellationError())
                        return
                    }
                    do {
                        let playbackRate = Self.playbackRate(
                            for: request.rateMultiplier
                        )
                        let engine = try loadedEngine(
                            Self.engineConfiguration(for: playbackRate)
                        )
                        guard !cancellation.isRequested else {
                            throw CancellationError()
                        }
                        let audio = try synthesize(
                            request,
                            playbackRate: playbackRate,
                            using: engine,
                            cancellation: cancellation
                        )
                        continuation.resume(returning: audio)
                    } catch {
                        continuation.resume(throwing: error)
                    }
                }
            }
        } onCancel: {
            cancellation.request()
        }
    }

    private func loadedEngine(
        _ configuration: EngineConfiguration
    ) throws -> OpaquePointer {
        if let engine, engineConfiguration == configuration { return engine }
        if let engineConfiguration {
            logDebug(
                "[Letter][Speech][VieNeu] switching native configuration " +
                "threads=\(engineConfiguration.threadCount)->" +
                "\(configuration.threadCount) " +
                "vq=\(engineConfiguration.quantizerCount)->" +
                "\(configuration.quantizerCount)"
            )
        }
        destroyLoadedEngine()
        let created = try createEngine(configuration)
        engine = created
        engineConfiguration = configuration
        return created
    }

    private func createEngine(
        _ configuration: EngineConfiguration
    ) throws -> OpaquePointer {
        logDebug(
            "[Letter][Speech][VieNeu] preparing native ONNX engine " +
            "lm_threads=\(configuration.threadCount) " +
            "vq=\(configuration.quantizerCount) acoustic_codec_threads=1"
        )
#if DEBUG
        let preparationStart = DispatchTime.now().uptimeNanoseconds
        let resourceStart = ProcessResourceSnapshot.capture()
#endif
        guard let created = createNativeEngine(configuration) else {
            throw VieNeuSpeechSynthesisError.initializationFailed(
                "Unable to allocate the VieNeu engine."
            )
        }
        guard letter_vieneu_is_ready(created) == 1 else {
            let message = String(cString: letter_vieneu_last_error(created))
            letter_vieneu_destroy(created)
            Logger.error("[Letter][Speech][VieNeu] preparation failed: \(message)")
            throw VieNeuSpeechSynthesisError.initializationFailed(message)
        }
#if DEBUG
        let preparationElapsed = elapsedSeconds(since: preparationStart)
        let resources = ProcessResourceSnapshot.capture()
            .summary(
                since: resourceStart,
                elapsedSeconds: preparationElapsed
            )
        logDebug(
            "[Letter][Speech][VieNeu] native ONNX engine ready " +
            "lm_threads=\(configuration.threadCount) " +
            "vq=\(configuration.quantizerCount) acoustic_codec_threads=1 " +
            "wall=\(milliseconds(preparationElapsed))ms \(resources)"
        )
#endif
        return created
    }

    private func createNativeEngine(
        _ engineConfiguration: EngineConfiguration
    ) -> OpaquePointer? {
        var configuration = letter_vieneu_default_configuration()
        configuration.thread_count = engineConfiguration.threadCount
        configuration.quantizer_count = engineConfiguration.quantizerCount
        return models.modelDirectory.path.withCString { modelDirectory in
            models.onnxDirectory.path.withCString { onnxDirectory in
                models.codecDirectory.path.withCString { codecDirectory in
                    models.voicesJSON.path.withCString { voicesJSON in
                        models.g2pDictionary.path.withCString { g2pDictionary in
                            configuration.model_directory = modelDirectory
                            configuration.onnx_directory = onnxDirectory
                            configuration.codec_directory = codecDirectory
                            configuration.voices_json_path = voicesJSON
                            configuration.g2p_dictionary_path = g2pDictionary
                            return letter_vieneu_create(&configuration)
                        }
                    }
                }
            }
        }
    }

    private func destroyLoadedEngine() {
        guard let engine else {
            engineConfiguration = nil
            return
        }
        self.engine = nil
        engineConfiguration = nil
        letter_vieneu_destroy(engine)
    }

    private func synthesize(
        _ request: LocalSpeechSynthesisRequest,
        playbackRate: Float,
        using engine: OpaquePointer,
        cancellation: VieNeuSynthesisCancellation
    ) throws -> SynthesizedSpeechAudio {
        var options = letter_vieneu_default_synthesis_options()
        options.maximum_frames = 260
        options.maximum_characters = 224
        options.playback_rate = playbackRate
        var audio = letter_vieneu_audio()
        let synthesisText = normalizedWhitespace(in: request.text)
        let voiceID = selectedVoice().rawValue
#if DEBUG
        let synthesisStart = DispatchTime.now().uptimeNanoseconds
        let resourceStart = ProcessResourceSnapshot.capture()
#endif
        let result = synthesisText.withCString { text in
            options.text = text
            return voiceID.withCString { voice in
                options.voice_id = voice
                return letter_vieneu_synthesize(
                    engine,
                    &options,
                    cancellation.nativeHandle,
                    &audio
                )
            }
        }
        guard result == 0 else {
            if cancellation.isRequested {
                throw CancellationError()
            }
            let message = String(cString: letter_vieneu_last_error(engine))
            Logger.error("[Letter][Speech][VieNeu] synthesis failed: \(message)")
            throw VieNeuSpeechSynthesisError.synthesisFailed(
                message
            )
        }
        defer { letter_vieneu_audio_free(&audio) }
        guard let samples = audio.samples,
              audio.sample_count > 0,
              audio.sample_rate > 0 else {
            throw VieNeuSpeechSynthesisError.emptyAudio
        }
#if DEBUG
        let synthesisElapsed = elapsedSeconds(since: synthesisStart)
        let resources = ProcessResourceSnapshot.capture()
            .summary(
                since: resourceStart,
                elapsedSeconds: synthesisElapsed
            )
        logDebug(
            "[Letter][Speech][VieNeu] synthesized chars=\(synthesisText.count) " +
            String(format: "rate=%.2f ", playbackRate) +
            "lm_threads=\(Self.threadCount(for: playbackRate)) " +
            "vq=\(Self.quantizerCount(for: playbackRate)) " +
            "acoustic_codec_threads=1 " +
            "wall=\(milliseconds(synthesisElapsed))ms \(resources)"
        )
#endif
        return SynthesizedSpeechAudio(
            data: WaveEncoder.encode(
                samples: Array(
                    UnsafeBufferPointer(
                        start: samples,
                        count: audio.sample_count
                    )
                ),
                sampleRate: Int(audio.sample_rate)
            ),
            playbackRate: playbackRate
        )
    }

    private static func playbackRate(for multiplier: Double) -> Float {
        Float(min(max(multiplier, 0.5), 3))
    }

    private static func threadCount(for playbackRate: Float) -> Int32 {
        playbackRate >= highRateThreshold
            ? highRateThreadCount
            : sustainableThreadCount
    }

    private static func quantizerCount(for playbackRate: Float) -> Int32 {
        playbackRate >= highRateThreshold
            ? highRateQuantizerCount
            : fullQuantizerCount
    }

    private static func engineConfiguration(
        for playbackRate: Float
    ) -> EngineConfiguration {
        EngineConfiguration(
            threadCount: threadCount(for: playbackRate),
            quantizerCount: quantizerCount(for: playbackRate)
        )
    }

    private func normalizedWhitespace(in text: String) -> String {
        var result = ""
        var hasPendingSpace = false
        for character in text {
            if character.isWhitespace {
                hasPendingSpace = !result.isEmpty
                continue
            }
            if hasPendingSpace {
                result.append(" ")
                hasPendingSpace = false
            }
            result.append(character)
        }
        return result
    }

    private func elapsedSeconds(since start: UInt64) -> TimeInterval {
        TimeInterval(DispatchTime.now().uptimeNanoseconds - start)
            / 1_000_000_000
    }

    private func milliseconds(_ seconds: TimeInterval) -> UInt64 {
        UInt64(seconds * 1_000)
    }
}
