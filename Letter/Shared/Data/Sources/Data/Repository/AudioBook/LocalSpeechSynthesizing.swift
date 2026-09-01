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

public struct SynthesizedSpeechPCMChunk: Sendable {
    public let samples: [Float]
    public let sampleRate: Int
    public let playbackRate: Float

    public init(samples: [Float], sampleRate: Int, playbackRate: Float = 1) {
        self.samples = samples
        self.sampleRate = sampleRate
        self.playbackRate = playbackRate
    }
}

public enum LocalSpeechStreamingError: Error {
    case unsupported
}

public enum LocalSpeechLineBreakBehavior: Sendable, Equatable {
    case preferredBoundary
    case whitespace
}

public struct LocalSpeechChunkingOptions: Sendable {
    public let maximumLength: Int
    public let lineBreakBehavior: LocalSpeechLineBreakBehavior
    public let sentenceBoundaryPause: TimeInterval
    public let minorBoundaryPause: TimeInterval

    public init(
        maximumLength: Int,
        lineBreakBehavior: LocalSpeechLineBreakBehavior = .preferredBoundary,
        sentenceBoundaryPause: TimeInterval = 0,
        minorBoundaryPause: TimeInterval = 0
    ) {
        self.maximumLength = maximumLength
        self.lineBreakBehavior = lineBreakBehavior
        self.sentenceBoundaryPause = sentenceBoundaryPause
        self.minorBoundaryPause = minorBoundaryPause
    }

    public func pauseAfterChunk(_ text: String) -> TimeInterval {
        guard let boundary = text.last(where: { !$0.isWhitespace }) else { return 0 }
        if ".!?…".contains(boundary) { return sentenceBoundaryPause }
        if ",;:".contains(boundary) { return minorBoundaryPause }
        return 0
    }
}

public protocol LocalSpeechSynthesizing: Sendable {
    func prepare(for languageCode: String) async throws
    func chunkingOptions(for languageCode: String) -> LocalSpeechChunkingOptions
    func supportsPCMStreaming(for languageCode: String) -> Bool
    func synthesizePCMStream(
        _ request: LocalSpeechSynthesisRequest
    ) -> AsyncThrowingStream<SynthesizedSpeechPCMChunk, Error>
    func synthesize(_ request: LocalSpeechSynthesisRequest) async throws
        -> SynthesizedSpeechAudio
}

public extension LocalSpeechSynthesizing {
    func supportsPCMStreaming(for languageCode: String) -> Bool { false }

    func synthesizePCMStream(
        _ request: LocalSpeechSynthesisRequest
    ) -> AsyncThrowingStream<SynthesizedSpeechPCMChunk, Error> {
        AsyncThrowingStream { continuation in
            continuation.finish(throwing: LocalSpeechStreamingError.unsupported)
        }
    }
}
