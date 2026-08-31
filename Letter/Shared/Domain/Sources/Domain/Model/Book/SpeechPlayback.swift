import Foundation
import Utility

public enum SpeechPlaybackState: Sendable, Equatable {
    case stopped
    case playing
    case paused
}

public enum SpeechPlaybackFailure: Sendable, Equatable {
    case unavailable
    case googleUnavailable
    case googleFreeLimitReached
}

public struct SpeechPlaybackRequest: Sendable, Equatable {
    public let bookTitle: String
    public let chapterTitle: String
    public let chapterID: UUID
    public let text: String
    public let characterOffset: Int
    public let rateMultiplier: Double
    public let languageCode: String
    public init(bookTitle: String, chapterTitle: String, chapterID: UUID, text: String, characterOffset: Int, rateMultiplier: Double, languageCode: String) { self.bookTitle=bookTitle; self.chapterTitle=chapterTitle; self.chapterID=chapterID; self.text=text; self.characterOffset=characterOffset; self.rateMultiplier=rateMultiplier; self.languageCode=languageCode }
}

public struct SpeechPlaybackProgress: Sendable, Equatable {
    public let chapterID: UUID
    public let characterOffset: Int
    public let totalCharacterCount: Int
    public init(chapterID: UUID, characterOffset: Int, totalCharacterCount: Int) { self.chapterID=chapterID; self.characterOffset=characterOffset; self.totalCharacterCount=totalCharacterCount }

    public var fraction: Double {
        guard totalCharacterCount > 0 else { return 0 }
        return min(max(Double(characterOffset) / Double(totalCharacterCount), 0), 1)
    }
}
