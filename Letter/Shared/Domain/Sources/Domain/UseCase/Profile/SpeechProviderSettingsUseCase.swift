import Foundation

public enum SpeechProvider: String, CaseIterable, Sendable {
    case apple
    case offline
}

public struct SpeechProviderSettings: Equatable, Sendable {
    public let provider: SpeechProvider
    public let appleVoiceIDs: [BookLanguage: String]
    public let offlineModels: [BookLanguage: OfflineSpeechModel]
    public let offlineVoices: [OfflineSpeechModel: OfflineSpeechVoice]

    public init(
        provider: SpeechProvider,
        appleVoiceIDs: [BookLanguage: String],
        offlineModels: [BookLanguage: OfflineSpeechModel],
        offlineVoices: [OfflineSpeechModel: OfflineSpeechVoice]
    ) {
        self.provider = provider
        self.appleVoiceIDs = appleVoiceIDs
        self.offlineModels = offlineModels
        self.offlineVoices = offlineVoices
    }

    public func offlineModel(for language: BookLanguage) -> OfflineSpeechModel? {
        OfflineSpeechModel.resolve(offlineModels[language], for: language)
    }

    public func appleVoiceID(for language: BookLanguage) -> String? {
        appleVoiceIDs[language]
    }

    public func offlineVoice(for model: OfflineSpeechModel) -> OfflineSpeechVoice? {
        offlineVoices[model] ?? model.defaultVoice
    }
}

public protocol SpeechProviderSettingsUseCase: AnyObject, Sendable {
    func load() -> SpeechProviderSettings
    func save(
        provider: SpeechProvider,
        offlineModels: [BookLanguage: OfflineSpeechModel]
    ) -> SpeechProviderSettings
    func saveAppleVoiceID(_ voiceID: String, for language: BookLanguage) -> SpeechProviderSettings
    func saveOfflineVoice(
        _ voice: OfflineSpeechVoice,
        for model: OfflineSpeechModel
    ) -> SpeechProviderSettings
}

public final class ImpSpeechProviderSettingsUseCase: SpeechProviderSettingsUseCase {
    private let repository: any SpeechProviderSettingsRepository

    public init(repository: any SpeechProviderSettingsRepository) {
        self.repository = repository
    }

    public func load() -> SpeechProviderSettings {
        makeSettings(provider: repository.loadProvider())
    }

    public func save(
        provider: SpeechProvider,
        offlineModels: [BookLanguage: OfflineSpeechModel]
    ) -> SpeechProviderSettings {
        for (language, model) in offlineModels where model.language == language {
            repository.saveOfflineModel(model, for: language)
        }
        repository.saveProvider(provider)
        return makeSettings(provider: provider)
    }

    public func saveAppleVoiceID(
        _ voiceID: String,
        for language: BookLanguage
    ) -> SpeechProviderSettings {
        repository.saveAppleVoiceID(voiceID, for: language)
        return makeSettings(provider: repository.loadProvider())
    }

    public func saveOfflineVoice(
        _ voice: OfflineSpeechVoice,
        for model: OfflineSpeechModel
    ) -> SpeechProviderSettings {
        repository.saveOfflineVoice(voice, for: model)
        return makeSettings(provider: repository.loadProvider())
    }

    private func makeSettings(provider: SpeechProvider) -> SpeechProviderSettings {
        SpeechProviderSettings(
            provider: provider,
            appleVoiceIDs: Dictionary(
                uniqueKeysWithValues: BookLanguage.allCases.compactMap { language in
                    repository.loadAppleVoiceID(for: language).map { (language, $0) }
                }
            ),
            offlineModels: Dictionary(
                uniqueKeysWithValues: BookLanguage.allCases.compactMap { language in
                    repository.loadOfflineModel(for: language).map { (language, $0) }
                }
            ),
            offlineVoices: Dictionary(
                uniqueKeysWithValues: OfflineSpeechModel.allCases.compactMap { model in
                    repository.loadOfflineVoice(for: model).map { (model, $0) }
                }
            )
        )
    }
}
