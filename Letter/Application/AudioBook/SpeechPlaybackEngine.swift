import Foundation

@MainActor
protocol SpeechPlaybackEngine: AnyObject {
    var onProgress: ((SpeechPlaybackProgress) -> Void)? { get set }
    var onFinished: (() -> Void)? { get set }
    var onStateChanged: ((SpeechPlaybackState) -> Void)? { get set }

    func availableVoices() -> [SpeechVoice]
    func play(_ request: SpeechPlaybackRequest)
    func pause()
    func resume()
    func stop()
}
