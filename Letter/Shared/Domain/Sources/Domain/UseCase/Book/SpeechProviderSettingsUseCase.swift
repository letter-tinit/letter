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
    public let googleCloudVoice: GoogleCloudVoicePreference
    public let offlineModels: [BookLanguage: OfflineSpeechModel]
    public let offlineVoices: [OfflineSpeechModel: OfflineSpeechVoice]

    public init(
        provider: SpeechProvider,
        hasGoogleCloudAPIKey: Bool,
        googleCloudVoice: GoogleCloudVoicePreference,
        offlineModels: [BookLanguage: OfflineSpeechModel],
        offlineVoices: [OfflineSpeechModel: OfflineSpeechVoice]
    ) {
        self.provider = provider
        self.hasGoogleCloudAPIKey = hasGoogleCloudAPIKey
        self.googleCloudVoice = googleCloudVoice
        self.offlineModels = offlineModels
        self.offlineVoices = offlineVoices
    }

    public func offlineModel(for language: BookLanguage) -> OfflineSpeechModel {
        offlineModels[language] ?? OfflineSpeechModel.models(for: language)[0]
    }

    public func offlineVoice(for model: OfflineSpeechModel) -> OfflineSpeechVoice? {
        offlineVoices[model] ?? model.defaultVoice
    }
}

public enum SpeechProviderSettingsError: Error, Equatable {
    case missingGoogleCloudAPIKey
    case credentialStorageFailed
    case offlineModelUnavailable
}

public protocol OfflineSpeechModelPreparing: AnyObject, Sendable {
    func prepare(_ model: OfflineSpeechModel) async throws
}

public protocol SpeechProviderSettingsRepository: AnyObject, Sendable {
    func loadProvider() -> SpeechProvider
    func saveProvider(_ provider: SpeechProvider)
    func loadGoogleCloudVoice() -> GoogleCloudVoicePreference
    func saveGoogleCloudVoice(_ voice: GoogleCloudVoicePreference)
    func loadOfflineModel(for language: BookLanguage) -> OfflineSpeechModel
    func saveOfflineModel(_ model: OfflineSpeechModel, for language: BookLanguage)
    func loadOfflineVoice(for model: OfflineSpeechModel) -> OfflineSpeechVoice?
    func saveOfflineVoice(_ voice: OfflineSpeechVoice, for model: OfflineSpeechModel)
    func loadGoogleCloudAPIKey() -> String?
    func saveGoogleCloudAPIKey(_ apiKey: String) throws
    func removeGoogleCloudAPIKey() throws
}

public protocol SpeechProviderSettingsUseCase: AnyObject, Sendable {
    func load() -> SpeechProviderSettings
    func save(
        provider: SpeechProvider,
        offlineModels: [BookLanguage: OfflineSpeechModel],
        newGoogleCloudAPIKey: String?
    ) async throws -> SpeechProviderSettings
    func removeGoogleCloudCredential() throws -> SpeechProviderSettings
    func saveGoogleCloudVoice(_ voice: GoogleCloudVoicePreference) -> SpeechProviderSettings
    func saveOfflineVoice(
        _ voice: OfflineSpeechVoice,
        for model: OfflineSpeechModel
    ) -> SpeechProviderSettings
}

public final class ImpSpeechProviderSettingsUseCase: SpeechProviderSettingsUseCase {
    private let repository: any SpeechProviderSettingsRepository
    private let offlineSpeech: any OfflineSpeechModelPreparing

    public init(
        repository: any SpeechProviderSettingsRepository,
        offlineSpeech: any OfflineSpeechModelPreparing
    ) {
        self.repository = repository
        self.offlineSpeech = offlineSpeech
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
        if provider == .offline {
            do {
                try await offlineSpeech.prepare(
                    offlineModels[.vietnamese] ?? .piperVais1000
                )
            } catch {
                throw SpeechProviderSettingsError.offlineModelUnavailable
            }
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

    public func saveGoogleCloudVoice(
        _ voice: GoogleCloudVoicePreference
    ) -> SpeechProviderSettings {
        repository.saveGoogleCloudVoice(voice)
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
            googleCloudVoice: repository.loadGoogleCloudVoice(),
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
