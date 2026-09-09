import Foundation

public enum SpeechProvider: String, CaseIterable, Sendable {
    case apple
    case googleCloud
    case offline
}

public enum GoogleCloudVoicePreference: String, CaseIterable, Sendable {
    case femaleOne
    case femaleTwo
    case maleOne
    case maleTwo
}

public struct SpeechProviderSettings: Equatable, Sendable {
    public let provider: SpeechProvider
    public let hasGoogleCloudAPIKey: Bool
    public let appleVoiceIDs: [BookLanguage: String]
    public let googleCloudVoices: [BookLanguage: GoogleCloudVoicePreference]
    public let offlineModels: [BookLanguage: OfflineSpeechModel]
    public let offlineVoices: [OfflineSpeechModel: OfflineSpeechVoice]

    public init(
        provider: SpeechProvider,
        hasGoogleCloudAPIKey: Bool,
        appleVoiceIDs: [BookLanguage: String],
        googleCloudVoices: [BookLanguage: GoogleCloudVoicePreference],
        offlineModels: [BookLanguage: OfflineSpeechModel],
        offlineVoices: [OfflineSpeechModel: OfflineSpeechVoice]
    ) {
        self.provider = provider
        self.hasGoogleCloudAPIKey = hasGoogleCloudAPIKey
        self.appleVoiceIDs = appleVoiceIDs
        self.googleCloudVoices = googleCloudVoices
        self.offlineModels = offlineModels
        self.offlineVoices = offlineVoices
    }

    public func offlineModel(for language: BookLanguage) -> OfflineSpeechModel {
        offlineModels[language] ?? OfflineSpeechModel.models(for: language)[0]
    }

    public func googleCloudVoice(for language: BookLanguage) -> GoogleCloudVoicePreference {
        googleCloudVoices[language] ?? .femaleOne
    }

    public func appleVoiceID(for language: BookLanguage) -> String? {
        appleVoiceIDs[language]
    }

    public func offlineVoice(for model: OfflineSpeechModel) -> OfflineSpeechVoice? {
        offlineVoices[model] ?? model.defaultVoice
    }
}

public enum SpeechProviderSettingsError: Error, Equatable {
    case missingGoogleCloudAPIKey
    case credentialStorageFailed
}

public protocol SpeechProviderSettingsUseCase: AnyObject, Sendable {
    func load() -> SpeechProviderSettings
    func save(
        provider: SpeechProvider,
        offlineModels: [BookLanguage: OfflineSpeechModel],
        newGoogleCloudAPIKey: String?
    ) async throws -> SpeechProviderSettings
    func removeGoogleCloudCredential() throws -> SpeechProviderSettings
    func saveAppleVoiceID(_ voiceID: String, for language: BookLanguage) -> SpeechProviderSettings
    func saveGoogleCloudVoice(
        _ voice: GoogleCloudVoicePreference,
        for language: BookLanguage
    ) -> SpeechProviderSettings
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
        offlineModels: [BookLanguage: OfflineSpeechModel],
        newGoogleCloudAPIKey: String?
    ) async throws -> SpeechProviderSettings {
        let apiKey = normalizedAPIKey(newGoogleCloudAPIKey)
        do {
            if let apiKey { try repository.saveGoogleCloudAPIKey(apiKey) }
        } catch {
            throw SpeechProviderSettingsError.credentialStorageFailed
        }
        guard provider != .googleCloud || hasGoogleCloudCredential else {
            throw SpeechProviderSettingsError.missingGoogleCloudAPIKey
        }
        for (language, model) in offlineModels {
            repository.saveOfflineModel(model, for: language)
        }
        repository.saveProvider(provider)
        return makeSettings(provider: provider)
    }

    public func removeGoogleCloudCredential() throws -> SpeechProviderSettings {
        do {
            try repository.removeGoogleCloudAPIKey()
        } catch {
            throw SpeechProviderSettingsError.credentialStorageFailed
        }
        repository.saveProvider(.apple)
        return makeSettings(provider: .apple)
    }

    public func saveAppleVoiceID(
        _ voiceID: String,
        for language: BookLanguage
    ) -> SpeechProviderSettings {
        repository.saveAppleVoiceID(voiceID, for: language)
        return makeSettings(provider: repository.loadProvider())
    }

    public func saveGoogleCloudVoice(
        _ voice: GoogleCloudVoicePreference,
        for language: BookLanguage
    ) -> SpeechProviderSettings {
        repository.saveGoogleCloudVoice(voice, for: language)
        return makeSettings(provider: repository.loadProvider())
    }

    public func saveOfflineVoice(
        _ voice: OfflineSpeechVoice,
        for model: OfflineSpeechModel
    ) -> SpeechProviderSettings {
        repository.saveOfflineVoice(voice, for: model)
        return makeSettings(provider: repository.loadProvider())
    }

    private var hasGoogleCloudCredential: Bool {
        normalizedAPIKey(repository.loadGoogleCloudAPIKey()) != nil
    }

    private func makeSettings(provider: SpeechProvider) -> SpeechProviderSettings {
        SpeechProviderSettings(
            provider: provider,
            hasGoogleCloudAPIKey: hasGoogleCloudCredential,
            appleVoiceIDs: Dictionary(
                uniqueKeysWithValues: BookLanguage.allCases.compactMap { language in
                    repository.loadAppleVoiceID(for: language).map { (language, $0) }
                }
            ),
            googleCloudVoices: Dictionary(
                uniqueKeysWithValues: BookLanguage.allCases.map {
                    ($0, repository.loadGoogleCloudVoice(for: $0))
                }
            ),
            offlineModels: Dictionary(
                uniqueKeysWithValues: BookLanguage.allCases.map {
                    ($0, repository.loadOfflineModel(for: $0))
                }
            ),
            offlineVoices: Dictionary(
                uniqueKeysWithValues: OfflineSpeechModel.allCases.compactMap { model in
                    repository.loadOfflineVoice(for: model).map { (model, $0) }
                }
            )
        )
    }

    private func normalizedAPIKey(_ value: String?) -> String? {
        guard let value else { return nil }
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}
