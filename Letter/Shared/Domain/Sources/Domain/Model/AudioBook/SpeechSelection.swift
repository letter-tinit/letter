import Foundation

public enum SpeechSelection: Sendable, Equatable {
    case apple(voiceID: String?)
    case offline(model: OfflineSpeechModel, voice: OfflineSpeechVoice?)
}
