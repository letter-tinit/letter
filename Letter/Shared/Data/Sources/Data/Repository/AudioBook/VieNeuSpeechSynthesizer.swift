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
    private let models: BundledVieNeuModels
    private let selectedVoice: @Sendable () -> VieNeuVoice
    private let queue = DispatchQueue(
        label: "com.letter.vieneu-speech-synthesis",
        qos: .userInitiated
    )
    private var engine: OpaquePointer?

    public init(
        models: BundledVieNeuModels,
        selectedVoice: @escaping @Sendable () -> VieNeuVoice = { .phamTuyen }
    ) {
        self.models = models
        self.selectedVoice = selectedVoice
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

    deinit {
        if let engine { letter_vieneu_destroy(engine) }
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
            let playbackRate = Float(min(max(request.rateMultiplier, 0.5), 3))
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
                    let engine = try loadedEngine()
                    guard !cancellation.isRequested else {
                        throw CancellationError()
                    }
                    var options = letter_vieneu_default_synthesis_options()
                    options.maximum_frames = 260
                    options.maximum_characters = 224
                    options.playback_rate = playbackRate
                    let synthesisText = normalizedWhitespace(in: request.text)
                    let voiceID = selectedVoice().rawValue
                    let synthesisStart = DispatchTime.now().uptimeNanoseconds
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
                    logDebug(
                        "[Letter][Speech][VieNeu] streamed \(synthesisText.count) " +
                        "characters in \(elapsedMilliseconds(since: synthesisStart)) ms"
                    )
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
                        let engine = try loadedEngine()
                        guard !cancellation.isRequested else {
                            throw CancellationError()
                        }
                        let audio = try synthesize(
                            request,
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

    private func loadedEngine() throws -> OpaquePointer {
        if let engine { return engine }
        logDebug("[Letter][Speech][VieNeu] preparing native ONNX engine")
        let preparationStart = DispatchTime.now().uptimeNanoseconds
        var configuration = letter_vieneu_default_configuration()
        configuration.thread_count = 2
        let created = models.modelDirectory.path.withCString { modelDirectory in
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
        guard let created else {
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
        engine = created
        logDebug(
            "[Letter][Speech][VieNeu] native ONNX engine ready in " +
            "\(elapsedMilliseconds(since: preparationStart)) ms"
        )
        return created
    }

    private func synthesize(
        _ request: LocalSpeechSynthesisRequest,
        using engine: OpaquePointer,
        cancellation: VieNeuSynthesisCancellation
    ) throws -> SynthesizedSpeechAudio {
        var options = letter_vieneu_default_synthesis_options()
        options.maximum_frames = 260
        options.maximum_characters = 224
        options.playback_rate = Float(min(max(request.rateMultiplier, 0.5), 3))
        var audio = letter_vieneu_audio()
        let synthesisText = normalizedWhitespace(in: request.text)
        let voiceID = selectedVoice().rawValue
        let synthesisStart = DispatchTime.now().uptimeNanoseconds
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
        logDebug(
            "[Letter][Speech][VieNeu] synthesized \(synthesisText.count) characters " +
            "in \(elapsedMilliseconds(since: synthesisStart)) ms"
        )
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
            playbackRate: Float(min(max(request.rateMultiplier, 0.5), 3))
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

    private func elapsedMilliseconds(since start: UInt64) -> UInt64 {
        (DispatchTime.now().uptimeNanoseconds - start) / 1_000_000
    }
}
