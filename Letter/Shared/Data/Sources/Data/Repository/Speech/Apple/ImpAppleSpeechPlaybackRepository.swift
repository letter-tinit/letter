import AVFoundation
import Foundation
import Domain
import LetterSpeech
import Utility

@MainActor
public final class ImpAppleSpeechPlaybackRepository: SpeechPlaybackRepository {
    private let player = AppleSpeechPlayer()
    private let settings: any SpeechProviderSettingsRepository
    private let mediaController = SystemMediaController()
    private var activeRequest: SpeechPlaybackRequest?
    private var currentOffset = 0
    private var isPaused = false
    public var onProgress: ((SpeechPlaybackProgress) -> Void)?
    public var onFinished: (() -> Void)?
    public var onStateChanged: ((SpeechPlaybackState) -> Void)?
    public var onPreviousChapterRequested: (() -> Void)?
    public var onNextChapterRequested: (() -> Void)?
    public var onFailure: ((SpeechPlaybackFailure) -> Void)?

    public init(settings: any SpeechProviderSettingsRepository) {
        self.settings = settings
        bindPlayer()
        bindMediaControls()
    }

    public func play(_ request: SpeechPlaybackRequest) {
        stop()
        configureAudioSession()
        activeRequest = request
        currentOffset = request.characterOffset
        isPaused = false
        let language = BookLanguage(languageCode: request.languageCode)
        let voiceIdentifier = language
            .flatMap { settings.loadAppleVoiceID(for: $0) }
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
        isPaused = false
        mediaController.clear()
        player.stop()
    }

    public func skip(seconds: TimeInterval) {
        seek(seconds: seconds)
    }

    public func setChapterNavigation(previousEnabled: Bool, nextEnabled: Bool) {
        mediaController.setChapterNavigation(
            previousEnabled: previousEnabled,
            nextEnabled: nextEnabled
        )
    }

    private func bindPlayer() {
        player.onProgress = { [weak self] progress in
            guard let self else { return }
            currentOffset = progress.characterOffset
            updateSystemMediaState()
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
            isPaused = state == .paused
            if state == .stopped { activeRequest = nil }
            updateSystemMediaState()
            switch state {
            case .playing: onStateChanged?(.playing)
            case .paused: onStateChanged?(.paused)
            case .stopped: onStateChanged?(.stopped)
            }
        }
        player.onFinished = { [weak self] in
            guard let self else { return }
            isPaused = true
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

    private func bindMediaControls() {
        mediaController.onPlay = { [weak self] in self?.resume() }
        mediaController.onPause = { [weak self] in self?.pause() }
        mediaController.onToggle = { [weak self] in
            guard let self else { return }
            self.isPaused ? self.resume() : self.pause()
        }
        mediaController.onPreviousChapter = { [weak self] in
            self?.onPreviousChapterRequested?()
        }
        mediaController.onNextChapter = { [weak self] in
            self?.onNextChapterRequested?()
        }
        mediaController.onSkip = { [weak self] seconds in
            self?.seek(seconds: seconds)
        }
        mediaController.onSeekToTime = { [weak self] time in self?.seek(toPlaybackTime: time) }
    }

    private func seek(seconds: TimeInterval) {
        guard let activeRequest else { return }
        let delta = Int(seconds * 14)
        let target = min(max(currentOffset + delta, 0), activeRequest.text.utf16.count)
        play(activeRequest.withOffset(target))
    }

    private func seek(toPlaybackTime time: TimeInterval) {
        guard let activeRequest else { return }
        let duration = mediaController.playbackDuration(for: activeRequest)
        guard duration > 0 else { return }
        let fraction = min(max(time / duration, 0), 1)
        let target = Int(Double(activeRequest.text.utf16.count) * fraction)
        play(activeRequest.withOffset(target))
    }

    private func updateSystemMediaState() {
        guard let activeRequest else { return }
        mediaController.update(request: activeRequest, characterOffset: currentOffset, isPaused: isPaused)
    }
}
extension SpeechPlaybackRequest {
    public func withOffset(_ offset: Int) -> SpeechPlaybackRequest {
        SpeechPlaybackRequest(
            bookTitle: bookTitle,
            chapterTitle: chapterTitle,
            chapterID: chapterID,
            text: text,
            characterOffset: offset,
            rateMultiplier: rateMultiplier,
            languageCode: languageCode
        )
    }
}
