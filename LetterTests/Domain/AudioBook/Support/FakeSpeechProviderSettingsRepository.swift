@testable import Domain

final class FakeSpeechProviderSettingsRepository: SpeechProviderSettingsRepository, @unchecked Sendable {
    var provider: SpeechProvider = .apple
    var appleVoiceIDs: [BookLanguage: String] = [:]
    var offlineModels: [BookLanguage: OfflineSpeechModel] = [:]
    var offlineVoices: [OfflineSpeechModel: OfflineSpeechVoice] = [:]

    func loadProvider() -> SpeechProvider {
        provider
    }

    func saveProvider(_ provider: SpeechProvider) {
        self.provider = provider
    }

    func loadAppleVoiceID(for language: BookLanguage) -> String? {
        appleVoiceIDs[language]
    }

    func saveAppleVoiceID(_ voiceID: String, for language: BookLanguage) {
        appleVoiceIDs[language] = voiceID
    }

    func loadOfflineModel(for language: BookLanguage) -> OfflineSpeechModel? {
        offlineModels[language]
    }

    func saveOfflineModel(_ model: OfflineSpeechModel, for language: BookLanguage) {
        offlineModels[language] = model
    }

    func loadOfflineVoice(for model: OfflineSpeechModel) -> OfflineSpeechVoice? {
        offlineVoices[model]
    }

    func saveOfflineVoice(_ voice: OfflineSpeechVoice, for model: OfflineSpeechModel) {
        offlineVoices[model] = voice
    }
}
