import Foundation
import SherpaOnnx

private enum OfflineSpeechSynthesisError: Error {
    case emptyAudio
}

public final class SherpaOnnxSpeechSynthesizer: LocalSpeechSynthesizing, @unchecked Sendable {
    private let catalog: SherpaOnnxModelCatalog
    private let queue = DispatchQueue(label: "com.letter.offline-speech-synthesis", qos: .userInitiated)
    private var engines: [String: SherpaOnnxOfflineTtsWrapper] = [:]

    public init(models: BundledSherpaOnnxModels) {
        catalog = models.catalog
    }

    public func prepare(for languageCode: String) async throws {
        try await withCheckedThrowingContinuation { continuation in
            queue.async { [self] in
                do {
                    _ = try engine(for: catalog.model(for: languageCode))
                    continuation.resume()
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    public func chunkingOptions(
        for languageCode: String
    ) -> LocalSpeechChunkingOptions {
        LocalSpeechChunkingOptions(
            maximumLength: catalog.model(for: languageCode).preferredTextChunkLength
        )
    }

    public func synthesize(
        _ request: LocalSpeechSynthesisRequest
    ) async throws -> SynthesizedSpeechAudio {
        try await withCheckedThrowingContinuation { continuation in
            queue.async { [self] in
                do {
                    let model = catalog.model(for: request.languageCode)
                    let tts = try engine(for: model)
                    let config = SherpaOnnxGenerationConfigSwift(
                        silenceScale: model.silenceScale,
                        speed: Float(min(max(request.rateMultiplier, 0.5), 3)),
                        sid: model.speakerID
                    )
                    let generated = tts.generateWithConfig(
                        text: request.text,
                        config: config,
                        callback: nil,
                        arg: nil
                    )
                    let samples = generated.samples
                    guard !samples.isEmpty, generated.sampleRate > 0 else {
                        throw OfflineSpeechSynthesisError.emptyAudio
                    }
                    continuation.resume(
                        returning: SynthesizedSpeechAudio(
                            data: WaveEncoder.encode(
                                samples: samples,
                                sampleRate: Int(generated.sampleRate)
                            )
                        )
                    )
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    private func engine(
        for model: SherpaOnnxModelDescriptor
    ) throws -> SherpaOnnxOfflineTtsWrapper {
        if let engine = engines[model.engineCacheKey] { return engine }
        let engine = try SherpaOnnxEngineFactory.makeEngine(for: model)
        engines[model.engineCacheKey] = engine
        return engine
    }
}
