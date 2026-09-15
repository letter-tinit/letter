import Foundation

public struct SystemMediaState: Sendable, Equatable {
    public let title: String
    public let bookTitle: String
    public let identifier: String
    public let duration: TimeInterval
    public let elapsedTime: TimeInterval
    public let playbackState: SpeechPlaybackState

    public init(
        title: String, bookTitle: String, identifier: String,
        duration: TimeInterval, elapsedTime: TimeInterval,
        playbackState: SpeechPlaybackState
    ) {
        self.title = title
        self.bookTitle = bookTitle
        self.identifier = identifier
        self.duration = duration
        self.elapsedTime = elapsedTime
        self.playbackState = playbackState
    }
}
