@MainActor
public protocol AppleSpeechVoiceCatalogRepository: AnyObject {
    func availableVoices(for language: BookLanguage) -> [AppleSpeechVoice]
}
