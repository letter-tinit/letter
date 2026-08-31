import Foundation

public enum SpeechProvider: String, CaseIterable, Sendable {
    case apple
    case googleCloud
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

    public init(
        provider: SpeechProvider,
        hasGoogleCloudAPIKey: Bool,
        googleCloudVoice: GoogleCloudVoicePreference
    ) {
        self.provider = provider
        self.hasGoogleCloudAPIKey = hasGoogleCloudAPIKey
        self.googleCloudVoice = googleCloudVoice
    }
}

public enum SpeechProviderSettingsError: Error, Equatable {
    case missingGoogleCloudAPIKey
    case credentialStorageFailed
}

public protocol SpeechProviderSettingsRepository: AnyObject, Sendable {
    func loadProvider() -> SpeechProvider
    func saveProvider(_ provider: SpeechProvider)
    func loadGoogleCloudVoice() -> GoogleCloudVoicePreference
    func saveGoogleCloudVoice(_ voice: GoogleCloudVoicePreference)
    func loadGoogleCloudAPIKey() -> String?
    func saveGoogleCloudAPIKey(_ apiKey: String) throws
    func removeGoogleCloudAPIKey() throws
}

public protocol SpeechProviderSettingsUseCase: AnyObject {
    func load() -> SpeechProviderSettings
    func save(provider: SpeechProvider, newGoogleCloudAPIKey: String?) throws -> SpeechProviderSettings
    func removeGoogleCloudCredential() throws -> SpeechProviderSettings
    func saveGoogleCloudVoice(_ voice: GoogleCloudVoicePreference) -> SpeechProviderSettings
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
        newGoogleCloudAPIKey: String?
    ) throws -> SpeechProviderSettings {
        let apiKey = normalizedAPIKey(newGoogleCloudAPIKey)
        do {
            if let apiKey { try repository.saveGoogleCloudAPIKey(apiKey) }
        } catch {
            throw SpeechProviderSettingsError.credentialStorageFailed
        }
        guard provider != .googleCloud || hasGoogleCloudCredential else {
            throw SpeechProviderSettingsError.missingGoogleCloudAPIKey
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

    private var hasGoogleCloudCredential: Bool {
        normalizedAPIKey(repository.loadGoogleCloudAPIKey()) != nil
    }

    private func makeSettings(provider: SpeechProvider) -> SpeechProviderSettings {
        SpeechProviderSettings(
            provider: provider,
            hasGoogleCloudAPIKey: hasGoogleCloudCredential,
            googleCloudVoice: repository.loadGoogleCloudVoice()
        )
    }

    private func normalizedAPIKey(_ value: String?) -> String? {
        guard let value else { return nil }
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}
