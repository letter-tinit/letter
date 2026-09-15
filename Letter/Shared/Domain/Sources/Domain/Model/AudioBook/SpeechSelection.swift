import Foundation

public enum SpeechSelection: Sendable, Equatable {
    case apple(voiceID: String?)
    case googleCloud(voice: GoogleCloudVoicePreference)
    case offline(model: OfflineSpeechModel, voice: OfflineSpeechVoice?)
}
