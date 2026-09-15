import Foundation
import Domain

public final class UserDefaultsSpeechProviderSettingsRepository: SpeechProviderSettingsRepository, @unchecked Sendable {
    private let providerKey = "audioBook.speechProvider"
    private let appleVoiceKeyPrefix = "audioBook.appleVoice."
    private let offlineModelKeyPrefix = "audioBook.offlineModel."
    private let offlineVoiceKeyPrefix = "audioBook.offlineVoice."
    private let legacyOfflineVietnameseModelKey = "audioBook.offlineVietnameseModel"
    private let legacyVieNeuVoiceKey = "audioBook.vieNeuVoice"
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

    public func loadAppleVoiceID(for language: BookLanguage) -> String? {
        defaults.string(forKey: appleVoiceKey(for: language))
    }

    public func saveAppleVoiceID(_ voiceID: String, for language: BookLanguage) {
        defaults.set(voiceID, forKey: appleVoiceKey(for: language))
    }

    public func loadOfflineModel(for language: BookLanguage) -> OfflineSpeechModel? {
        let storedValue = defaults.string(forKey: offlineModelKey(for: language))
            ?? (language == .vietnamese
                ? defaults.string(forKey: legacyOfflineVietnameseModelKey)
                : nil)
        return OfflineSpeechModel.resolve(
            storedValue.flatMap(OfflineSpeechModel.init(rawValue:)), for: language
        )
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

    private func offlineModelKey(for language: BookLanguage) -> String {
        offlineModelKeyPrefix + language.rawValue
    }

    private func appleVoiceKey(for language: BookLanguage) -> String {
        appleVoiceKeyPrefix + language.rawValue
    }

    private func offlineVoiceKey(for model: OfflineSpeechModel) -> String {
        offlineVoiceKeyPrefix + model.rawValue
    }

}

public final class InMemorySpeechProviderSettingsRepository: SpeechProviderSettingsRepository, @unchecked Sendable {
    private let lock = NSLock()
    private var provider: SpeechProvider = .apple
    private var appleVoiceIDs: [BookLanguage: String] = [:]
    private var offlineModels = OfflineSpeechModel.defaultModels
    private var offlineVoices: [OfflineSpeechModel: OfflineSpeechVoice] = [
        .vieNeuV3Turbo: .ngocLinh
    ]

    public init() {}

    public func loadProvider() -> SpeechProvider { lock.withLock { provider } }
    public func saveProvider(_ provider: SpeechProvider) { lock.withLock { self.provider = provider } }
    public func loadAppleVoiceID(for language: BookLanguage) -> String? {
        lock.withLock { appleVoiceIDs[language] }
    }
    public func saveAppleVoiceID(_ voiceID: String, for language: BookLanguage) {
        lock.withLock { appleVoiceIDs[language] = voiceID }
    }
    public func loadOfflineModel(for language: BookLanguage) -> OfflineSpeechModel? {
        lock.withLock { OfflineSpeechModel.resolve(offlineModels[language], for: language) }
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
}
