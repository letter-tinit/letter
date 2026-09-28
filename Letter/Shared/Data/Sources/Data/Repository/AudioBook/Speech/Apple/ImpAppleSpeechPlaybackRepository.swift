import AVFoundation
import Foundation
import Domain
import LetterSpeech

@MainActor
public final class ImpAppleSpeechPlaybackRepository: SpeechPlaybackRepository {
    private let player = AppleSpeechPlayer()
    private var activeRequest: SpeechPlaybackRequest?
    private var currentOffset = 0
    public var onProgress: ((SpeechPlaybackProgress) -> Void)?
    public var onFinished: (() -> Void)?
    public var onStateChanged: ((SpeechPlaybackState) -> Void)?
    public var onFailure: ((SpeechPlaybackFailure) -> Void)?

    public init() {
        bindPlayer()
    }

    public func play(_ request: SpeechPlaybackRequest) {
        stop()
        configureAudioSession()
        activeRequest = request
        currentOffset = request.characterOffset
        guard case .apple(let voiceIdentifier) = request.selection else {
            onFailure?(.unavailable)
            return
        }
        onProgress?(SpeechPlaybackProgress(
            chapterID: request.chapterID, characterOffset: currentOffset,
            totalCharacterCount: request.text.utf16.count
        ))
        player.play(
            AppleSpeechPlaybackRequest(
                text: request.text,
                languageCode: request.languageCode,
                voiceIdentifier: voiceIdentifier,
                characterOffset: request.characterOffset,
                rateMultiplier: request.rateMultiplier
            )
        )
    }

    public func pause() {
        player.pause()
    }

    public func resume() {
        player.resume()
    }

    public func stop() {
        activeRequest = nil
        currentOffset = 0
        player.stop()
    }

    public func skip(seconds: TimeInterval) {
        seek(seconds: seconds)
    }

    private func bindPlayer() {
        player.onProgress = { [weak self] progress in
            guard let self else { return }
            currentOffset = progress.characterOffset
            guard let activeRequest else { return }
            onProgress?(
                SpeechPlaybackProgress(
                    chapterID: activeRequest.chapterID,
                    characterOffset: progress.characterOffset,
                    totalCharacterCount: progress.totalCharacterCount
                )
            )
        }
        player.onStateChanged = { [weak self] state in
            guard let self else { return }
            if state == .stopped { activeRequest = nil }
            switch state {
            case .playing: onStateChanged?(.playing)
            case .paused: onStateChanged?(.paused)
            case .stopped: onStateChanged?(.stopped)
            }
        }
        player.onFinished = { [weak self] in
            guard let self else { return }
            try? AVAudioSession.sharedInstance().setActive(
                false,
                options: .notifyOthersOnDeactivation
            )
            onFinished?()
        }
    }

    private func configureAudioSession() {
        let session = AVAudioSession.sharedInstance()
        try? session.setCategory(
            .playback,
            mode: .spokenAudio,
            policy: .longFormAudio,
            options: []
        )
        try? session.setActive(true)
    }

    private func seek(seconds: TimeInterval) {
        guard let activeRequest else { return }
        // Preserve Apple's existing rate-independent relative skip behavior.
        let target = SpeechPlaybackTiming(
            characterCount: activeRequest.text.utf16.count, rate: 1
        ).skippedOffset(from: currentOffset, seconds: seconds)
        play(activeRequest.withOffset(target))
    }
}
