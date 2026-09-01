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
    public let playbackRate: Float

    public init(data: Data, playbackRate: Float = 1) {
        self.data = data
        self.playbackRate = playbackRate
    }
}

public protocol LocalSpeechSynthesizing: Sendable {
    func prepare(for languageCode: String) async throws
    func preferredTextChunkLength(for languageCode: String) -> Int
    func synthesize(_ request: LocalSpeechSynthesisRequest) async throws
        -> SynthesizedSpeechAudio
}
