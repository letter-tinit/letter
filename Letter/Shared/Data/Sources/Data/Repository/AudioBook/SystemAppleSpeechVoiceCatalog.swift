import AVFoundation
import Domain

@MainActor
public final class SystemAppleSpeechVoiceCatalog: AppleSpeechVoiceCatalog {
    public init() {}

    public func availableVoices(for language: BookLanguage) -> [AppleSpeechVoice] {
        AVSpeechSynthesisVoice.speechVoices()
            .filter { $0.language.lowercased().hasPrefix(language.languageCode.prefix(2).lowercased()) }
            .map { AppleSpeechVoice(id: $0.identifier, name: $0.name, language: language) }
            .sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
    }
}
