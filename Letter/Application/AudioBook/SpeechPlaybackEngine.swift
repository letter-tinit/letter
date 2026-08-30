import Foundation

@MainActor
protocol SpeechPlaybackEngine: AnyObject {
    var onProgress: ((SpeechPlaybackProgress) -> Void)? { get set }
    var onFinished: (() -> Void)? { get set }
    var onStateChanged: ((SpeechPlaybackState) -> Void)? { get set }
    var onPreviousChapterRequested: (() -> Void)? { get set }
    var onNextChapterRequested: (() -> Void)? { get set }

    func play(_ request: SpeechPlaybackRequest)
    func pause()
    func resume()
    func stop()
    func setChapterNavigation(previousEnabled: Bool, nextEnabled: Bool)
}
