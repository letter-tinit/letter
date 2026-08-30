import Foundation

enum SpeechPlaybackState: Sendable, Equatable {
    case stopped
    case playing
    case paused
}

struct SpeechPlaybackRequest: Sendable, Equatable {
    let bookTitle: String
    let chapterTitle: String
    let chapterID: UUID
    let text: String
    let characterOffset: Int
    let rateMultiplier: Double
    let languageCode: String
}

struct SpeechPlaybackProgress: Sendable, Equatable {
    let chapterID: UUID
    let characterOffset: Int
    let totalCharacterCount: Int

    var fraction: Double {
        guard totalCharacterCount > 0 else { return 0 }
        return min(max(Double(characterOffset) / Double(totalCharacterCount), 0), 1)
    }
}
