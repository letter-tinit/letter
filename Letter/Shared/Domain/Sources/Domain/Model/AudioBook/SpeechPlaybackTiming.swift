import Foundation

/// Estimated chapter timing; actual audio-buffer timing remains with the player.
public struct SpeechPlaybackTiming: Sendable {
    private static let charactersPerSecond = 14.0
    public let characterCount: Int
    public let rate: Double

    public init(characterCount: Int, rate: Double) {
        self.characterCount = characterCount
        self.rate = rate
    }

    public var duration: TimeInterval {
        Double(characterCount) / Self.charactersPerSecond / max(rate, 0.1)
    }

    public func elapsedTime(at offset: Int) -> TimeInterval {
        guard characterCount > 0 else { return 0 }
        return duration * Double(offset) / Double(characterCount)
    }

    public func characterOffset(at time: TimeInterval) -> Int {
        guard duration > 0 else { return 0 }
        return Int(Double(characterCount) * min(max(time / duration, 0), 1))
    }

    public func skippedOffset(from offset: Int, seconds: TimeInterval) -> Int {
        let delta = Int(seconds * Self.charactersPerSecond * rate)
        return min(max(offset + delta, 0), characterCount)
    }
}
