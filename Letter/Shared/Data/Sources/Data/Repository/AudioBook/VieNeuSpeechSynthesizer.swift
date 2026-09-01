import CVieNeuRuntime
import Foundation
import Utility

private enum VieNeuSpeechSynthesisError: Error {
    case initializationFailed(String)
    case synthesisFailed(String)
    case emptyAudio
}

public final class VieNeuSpeechSynthesizer: LocalSpeechSynthesizing, @unchecked Sendable {
    private let models: BundledVieNeuModels
    private let voiceID: String?
    private let queue = DispatchQueue(
        label: "com.letter.vieneu-speech-synthesis",
        qos: .userInitiated
    )
    private var engine: OpaquePointer?

    public init(models: BundledVieNeuModels, voiceID: String? = nil) {
        self.models = models
        self.voiceID = voiceID
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

    public func preferredTextChunkLength(for languageCode: String) -> Int {
        220
    }

    public func synthesize(
        _ request: LocalSpeechSynthesisRequest
    ) async throws -> SynthesizedSpeechAudio {
        try await withCheckedThrowingContinuation { continuation in
            queue.async { [self] in
                do {
                    let engine = try loadedEngine()
                    let audio = try synthesize(request, using: engine)
                    continuation.resume(returning: audio)
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    private func loadedEngine() throws -> OpaquePointer {
        if let engine { return engine }
        logDebug("[Letter][Speech][VieNeu] preparing native ONNX engine")
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
        logDebug("[Letter][Speech][VieNeu] native ONNX engine ready")
        return created
    }

    private func synthesize(
        _ request: LocalSpeechSynthesisRequest,
        using engine: OpaquePointer
    ) throws -> SynthesizedSpeechAudio {
        var options = letter_vieneu_default_synthesis_options()
        options.maximum_frames = 260
        options.maximum_characters = 224
        var audio = letter_vieneu_audio()
        let result = request.text.withCString { text in
            options.text = text
            if let voiceID {
                return voiceID.withCString { voice in
                    options.voice_id = voice
                    return letter_vieneu_synthesize(engine, &options, &audio)
                }
            }
            return letter_vieneu_synthesize(engine, &options, &audio)
        }
        guard result == 0 else {
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
}
