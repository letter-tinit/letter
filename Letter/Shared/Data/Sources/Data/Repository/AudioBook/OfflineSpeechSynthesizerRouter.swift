import Domain
import Foundation

public final class OfflineSpeechSynthesizerRouter:
    LocalSpeechSynthesizing,
    OfflineSpeechModelPreparing,
    @unchecked Sendable
{
    private let settings: any SpeechProviderSettingsRepository
    private let sherpa: any LocalSpeechSynthesizing
    private let vieNeu: any LocalSpeechSynthesizing

    public init(
        settings: any SpeechProviderSettingsRepository,
        sherpa: any LocalSpeechSynthesizing,
        vieNeu: any LocalSpeechSynthesizing
    ) {
        self.settings = settings
        self.sherpa = sherpa
        self.vieNeu = vieNeu
    }

    public func prepare(_ model: OfflineVietnameseModel) async throws {
        try await synthesizer(for: model).prepare(for: "vi-VN")
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
        guard languageCode
            .split(separator: "-", maxSplits: 1)
            .first?
            .lowercased() == "vi" else {
            return sherpa
        }
        return synthesizer(for: settings.loadOfflineVietnameseModel())
    }

    private func synthesizer(
        for model: OfflineVietnameseModel
    ) -> any LocalSpeechSynthesizing {
        switch model {
        case .piperVais1000: sherpa
        case .vieNeuV3Turbo: vieNeu
        }
    }
}
