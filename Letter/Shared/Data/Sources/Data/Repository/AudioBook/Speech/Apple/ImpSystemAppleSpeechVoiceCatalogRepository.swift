import Domain
import LetterSpeech

@MainActor
public final class ImpSystemAppleSpeechVoiceCatalogRepository: AppleSpeechVoiceCatalogRepository {
    public init() {}

    public func availableVoices(for language: BookLanguage) -> [AppleSpeechVoice] {
        AppleSpeechVoiceCatalog.availableVoices(languageCode: language.languageCode)
            .map { AppleSpeechVoice(id: $0.id, name: $0.name, language: language) }
    }
}
