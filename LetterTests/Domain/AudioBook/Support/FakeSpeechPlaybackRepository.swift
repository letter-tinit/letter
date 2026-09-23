import Foundation
@testable import Domain

@MainActor
final class FakeSpeechPlaybackRepository: SpeechPlaybackRepository {
    var onProgress: ((SpeechPlaybackProgress) -> Void)?
    var onFinished: (() -> Void)?
    var onStateChanged: ((SpeechPlaybackState) -> Void)?
    var onFailure: ((SpeechPlaybackFailure) -> Void)?

    var playedRequests: [SpeechPlaybackRequest] = []
    var pauseCount = 0
    var resumeCount = 0
    var stopCount = 0
    var skippedSeconds: [TimeInterval] = []

    func play(_ request: SpeechPlaybackRequest) {
        playedRequests.append(request)
    }

    func pause() {
        pauseCount += 1
    }

    func resume() {
        resumeCount += 1
    }

    func stop() {
        stopCount += 1
    }

    func skip(seconds: TimeInterval) {
        skippedSeconds.append(seconds)
    }
}
