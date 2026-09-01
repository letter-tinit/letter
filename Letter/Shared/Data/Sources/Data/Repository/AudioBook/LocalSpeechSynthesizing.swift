import Foundation

public struct LocalSpeechSynthesisRequest: Sendable {
    public let text: String
    public let languageCode: String
    public let rateMultiplier: Double

    public init(text: String, languageCode: String, rateMultiplier: Double) {
        self.text = text
        self.languageCode = languageCode
        self.rateMultiplier = rateMultiplier
    }
}

public struct SynthesizedSpeechAudio: Sendable {
    public let data: Data

    public init(data: Data) {
        self.data = data
    }
}

public protocol LocalSpeechSynthesizing: Sendable {
    func preferredTextChunkLength(for languageCode: String) -> Int
    func synthesize(_ request: LocalSpeechSynthesisRequest) async throws
        -> SynthesizedSpeechAudio
}
