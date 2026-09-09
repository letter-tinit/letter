import Foundation
import Utility

@MainActor
public protocol SpeechPlaybackRepository: AnyObject {
    var onProgress: ((SpeechPlaybackProgress) -> Void)? { get set }
    var onFinished: (() -> Void)? { get set }
    var onStateChanged: ((SpeechPlaybackState) -> Void)? { get set }
    var onPreviousChapterRequested: (() -> Void)? { get set }
    var onNextChapterRequested: (() -> Void)? { get set }
    var onFailure: ((SpeechPlaybackFailure) -> Void)? { get set }

    func play(_ request: SpeechPlaybackRequest)
    func pause()
    func resume()
    func stop()
    func skip(seconds: TimeInterval)
    func setChapterNavigation(previousEnabled: Bool, nextEnabled: Bool)
}
