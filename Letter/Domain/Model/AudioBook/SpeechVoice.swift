import Foundation

enum SpeechVoiceQuality: Int, Codable, Sendable, Comparable {
    case standard
    case enhanced
    case premium

    static func < (lhs: SpeechVoiceQuality, rhs: SpeechVoiceQuality) -> Bool {
        lhs.rawValue < rhs.rawValue
    }
}

struct SpeechVoice: Identifiable, Hashable, Sendable {
    let id: String
    let name: String
    let languageCode: String
    let quality: SpeechVoiceQuality
}
