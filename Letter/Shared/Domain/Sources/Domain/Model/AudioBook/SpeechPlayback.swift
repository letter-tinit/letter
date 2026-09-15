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
    case offlineUnavailable
}

public struct SpeechPlaybackRequest: Sendable, Equatable {
    public let bookTitle: String
    public let chapterTitle: String
    public let chapterID: UUID
    public let text: String
    public let characterOffset: Int
    public let rateMultiplier: Double
    public let languageCode: String
    public let selection: SpeechSelection
    public init(
        bookTitle: String, chapterTitle: String, chapterID: UUID,
        text: String, characterOffset: Int, rateMultiplier: Double,
        languageCode: String, selection: SpeechSelection
    ) {
        self.bookTitle = bookTitle
        self.chapterTitle = chapterTitle
        self.chapterID = chapterID
        self.text = text
        self.characterOffset = characterOffset
        self.rateMultiplier = rateMultiplier
        self.languageCode = languageCode
        self.selection = selection
    }

    public func withOffset(_ offset: Int, selection: SpeechSelection? = nil) -> Self {
        Self(
            bookTitle: bookTitle, chapterTitle: chapterTitle, chapterID: chapterID,
            text: text, characterOffset: offset, rateMultiplier: rateMultiplier,
            languageCode: languageCode, selection: selection ?? self.selection
        )
    }

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
