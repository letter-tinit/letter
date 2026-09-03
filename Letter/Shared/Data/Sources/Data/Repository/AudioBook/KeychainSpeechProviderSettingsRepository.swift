import Foundation
import Security
import Domain

public final class KeychainSpeechProviderSettingsRepository: SpeechProviderSettingsRepository, @unchecked Sendable {
    private let providerKey = "audioBook.speechProvider"
    private let voiceKey = "audioBook.googleCloudVoice"
    private let offlineModelKeyPrefix = "audioBook.offlineModel."
    private let offlineVoiceKeyPrefix = "audioBook.offlineVoice."
    private let legacyOfflineVietnameseModelKey = "audioBook.offlineVietnameseModel"
    private let legacyVieNeuVoiceKey = "audioBook.vieNeuVoice"
    private let keychainService = "com.lettertinit.Letter.google-cloud-tts"
    private let keychainAccount = "api-key"
    private let defaults: UserDefaults

    public init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    public func loadProvider() -> SpeechProvider {
        guard let value = defaults.string(forKey: providerKey),
              let provider = SpeechProvider(rawValue: value) else { return .apple }
        return provider
    }

    public func saveProvider(_ provider: SpeechProvider) {
        defaults.set(provider.rawValue, forKey: providerKey)
    }

    public func loadGoogleCloudVoice() -> GoogleCloudVoicePreference {
        defaults.string(forKey: voiceKey)
            .flatMap(GoogleCloudVoicePreference.init(rawValue:)) ?? .femaleOne
    }

    public func saveGoogleCloudVoice(_ voice: GoogleCloudVoicePreference) {
        defaults.set(voice.rawValue, forKey: voiceKey)
    }

    public func loadOfflineModel(for language: BookLanguage) -> OfflineSpeechModel {
        let storedValue = defaults.string(forKey: offlineModelKey(for: language))
            ?? (language == .vietnamese
                ? defaults.string(forKey: legacyOfflineVietnameseModelKey)
                : nil)
        return storedValue
            .flatMap(OfflineSpeechModel.init(rawValue:))
            ?? OfflineSpeechModel.models(for: language)[0]
    }

    public func saveOfflineModel(_ model: OfflineSpeechModel, for language: BookLanguage) {
        defaults.set(model.rawValue, forKey: offlineModelKey(for: language))
    }

    public func loadOfflineVoice(for model: OfflineSpeechModel) -> OfflineSpeechVoice? {
        let storedValue = defaults.string(forKey: offlineVoiceKey(for: model))
            ?? (model == .vieNeuV3Turbo
                ? defaults.string(forKey: legacyVieNeuVoiceKey)
                : nil)
        return storedValue
            .map(OfflineSpeechVoice.init(rawValue:))
            ?? model.defaultVoice
    }

    public func saveOfflineVoice(_ voice: OfflineSpeechVoice, for model: OfflineSpeechModel) {
        defaults.set(voice.rawValue, forKey: offlineVoiceKey(for: model))
    }

    public func loadGoogleCloudAPIKey() -> String? {
        var query = baseQuery
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne
        var result: CFTypeRef?
        guard SecItemCopyMatching(query as CFDictionary, &result) == errSecSuccess,
              let data = result as? Data else { return nil }
        return String(data: data, encoding: .utf8)
    }

    public func saveGoogleCloudAPIKey(_ apiKey: String) throws {
        let data = Data(apiKey.utf8)
        let update = [kSecValueData as String: data]
        let status = SecItemUpdate(baseQuery as CFDictionary, update as CFDictionary)
        if status == errSecSuccess { return }
        guard status == errSecItemNotFound else { throw KeychainError(status: status) }

        var item = baseQuery
        item[kSecValueData as String] = data
        item[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        let addStatus = SecItemAdd(item as CFDictionary, nil)
        guard addStatus == errSecSuccess else { throw KeychainError(status: addStatus) }
    }

    public func removeGoogleCloudAPIKey() throws {
        let status = SecItemDelete(baseQuery as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw KeychainError(status: status)
        }
    }

    private var baseQuery: [String: Any] {
        [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: keychainService,
            kSecAttrAccount as String: keychainAccount,
            kSecAttrSynchronizable as String: false
        ]
    }

    private func offlineModelKey(for language: BookLanguage) -> String {
        offlineModelKeyPrefix + language.rawValue
    }

    private func offlineVoiceKey(for model: OfflineSpeechModel) -> String {
        offlineVoiceKeyPrefix + model.rawValue
    }

    private struct KeychainError: Error {
        let status: OSStatus
    }
}

public final class InMemorySpeechProviderSettingsRepository: SpeechProviderSettingsRepository, @unchecked Sendable {
    private let lock = NSLock()
    private var provider: SpeechProvider = .apple
    private var apiKey: String?
    private var voice: GoogleCloudVoicePreference = .femaleOne
    private var offlineModels = Dictionary(
        uniqueKeysWithValues: BookLanguage.allCases.map {
            ($0, OfflineSpeechModel.models(for: $0)[0])
        }
    )
    private var offlineVoices: [OfflineSpeechModel: OfflineSpeechVoice] = [
        .vieNeuV3Turbo: .phamTuyen
    ]

    public init() {}

    public func loadProvider() -> SpeechProvider { lock.withLock { provider } }
    public func saveProvider(_ provider: SpeechProvider) { lock.withLock { self.provider = provider } }
    public func loadGoogleCloudVoice() -> GoogleCloudVoicePreference { lock.withLock { voice } }
    public func saveGoogleCloudVoice(_ voice: GoogleCloudVoicePreference) { lock.withLock { self.voice = voice } }
    public func loadOfflineModel(for language: BookLanguage) -> OfflineSpeechModel {
        lock.withLock { offlineModels[language] ?? OfflineSpeechModel.models(for: language)[0] }
    }
    public func saveOfflineModel(_ model: OfflineSpeechModel, for language: BookLanguage) {
        lock.withLock { offlineModels[language] = model }
    }
    public func loadOfflineVoice(for model: OfflineSpeechModel) -> OfflineSpeechVoice? {
        lock.withLock { offlineVoices[model] ?? model.defaultVoice }
    }
    public func saveOfflineVoice(_ voice: OfflineSpeechVoice, for model: OfflineSpeechModel) {
        lock.withLock { offlineVoices[model] = voice }
    }
    public func loadGoogleCloudAPIKey() -> String? { lock.withLock { apiKey } }
    public func saveGoogleCloudAPIKey(_ apiKey: String) throws { lock.withLock { self.apiKey = apiKey } }
    public func removeGoogleCloudAPIKey() throws { lock.withLock { apiKey = nil } }
}
