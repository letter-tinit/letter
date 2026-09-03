import Domain
import Foundation

public final class OfflineSpeechSynthesizerRouter:
    LocalSpeechSynthesizing,
    OfflineSpeechModelPreparing,
    @unchecked Sendable
{
    private let settings: any SpeechProviderSettingsRepository
    private let synthesizers: [OfflineSpeechModel: any LocalSpeechSynthesizing]

    public init(
        settings: any SpeechProviderSettingsRepository,
        synthesizers: [OfflineSpeechModel: any LocalSpeechSynthesizing]
    ) {
        self.settings = settings
        self.synthesizers = synthesizers
    }

    public func prepare(_ model: OfflineSpeechModel) async throws {
        try await synthesizer(for: model).prepare(for: model.language.languageCode)
    }

    public func prepare(for languageCode: String) async throws {
        try await synthesizer(for: languageCode).prepare(for: languageCode)
    }

    public func chunkingOptions(
        for languageCode: String
    ) -> LocalSpeechChunkingOptions {
        synthesizer(for: languageCode).chunkingOptions(for: languageCode)
    }

    public func supportsPCMStreaming(for languageCode: String) -> Bool {
        synthesizer(for: languageCode).supportsPCMStreaming(for: languageCode)
    }

    public func synthesizePCMStream(
        _ request: LocalSpeechSynthesisRequest
    ) -> AsyncThrowingStream<SynthesizedSpeechPCMChunk, Error> {
        synthesizer(for: request.languageCode).synthesizePCMStream(request)
    }

    public func synthesize(
        _ request: LocalSpeechSynthesisRequest
    ) async throws -> SynthesizedSpeechAudio {
        try await synthesizer(for: request.languageCode).synthesize(request)
    }

    private func synthesizer(
        for languageCode: String
    ) -> any LocalSpeechSynthesizing {
        guard let language = BookLanguage(languageCode: languageCode) else {
            return synthesizer(for: .matchaLJSpeech)
        }
        return synthesizer(for: settings.loadOfflineModel(for: language))
    }

    private func synthesizer(
        for model: OfflineSpeechModel
    ) -> any LocalSpeechSynthesizing {
        guard let synthesizer = synthesizers[model] else {
            preconditionFailure("Offline speech model is not registered: \(model.rawValue)")
        }
        return synthesizer
    }
}
