import Foundation

/// A voice installed by the operating system, represented without exposing
/// AVFoundation outside the Data layer.
public struct AppleSpeechVoice: Identifiable, Equatable, Sendable, Hashable {
    public let id: String
    public let name: String
    public let language: BookLanguage

    public init(id: String, name: String, language: BookLanguage) {
        self.id = id
        self.name = name
        self.language = language
    }
}

@MainActor
public protocol AppleSpeechVoiceCatalog: AnyObject {
    func availableVoices(for language: BookLanguage) -> [AppleSpeechVoice]
}
