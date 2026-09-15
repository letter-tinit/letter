public protocol SpeechProviderSettingsRepository: AnyObject, Sendable {
    func loadProvider() -> SpeechProvider
    func saveProvider(_ provider: SpeechProvider)
    func loadAppleVoiceID(for language: BookLanguage) -> String?
    func saveAppleVoiceID(_ voiceID: String, for language: BookLanguage)
    func loadOfflineModel(for language: BookLanguage) -> OfflineSpeechModel?
    func saveOfflineModel(_ model: OfflineSpeechModel, for language: BookLanguage)
    func loadOfflineVoice(for model: OfflineSpeechModel) -> OfflineSpeechVoice?
    func saveOfflineVoice(_ voice: OfflineSpeechVoice, for model: OfflineSpeechModel)
}
