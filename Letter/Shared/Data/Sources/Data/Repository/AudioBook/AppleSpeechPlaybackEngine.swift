import AVFoundation
import Foundation
import Domain
import Utility

@MainActor
public final class AppleSpeechPlaybackEngine: NSObject, SpeechPlaybackRepository, AVSpeechSynthesizerDelegate {
    private struct UtteranceContext {
        let generation: UUID
        let chapterID: UUID
        let baseOffset: Int
        let totalCharacterCount: Int
    }

    private let synthesizer = AVSpeechSynthesizer()
    private let settings: any SpeechProviderSettingsRepository
    private let mediaController = SystemMediaController()
    private var generation = UUID()
    private var contexts: [ObjectIdentifier: UtteranceContext] = [:]
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
        super.init()
        synthesizer.delegate = self
        synthesizer.usesApplicationAudioSession = true
        bindMediaControls()
    }

    public func play(_ request: SpeechPlaybackRequest) {
        stop()
        configureAudioSession()
        activeRequest = request
        currentOffset = request.characterOffset
        isPaused = false
        generation = UUID()
        let activeGeneration = generation
        let language = BookLanguage(languageCode: request.languageCode)
        let voice = language
            .flatMap { settings.loadAppleVoiceID(for: $0) }
            .flatMap(AVSpeechSynthesisVoice.init(identifier:))
            ?? AVSpeechSynthesisVoice(language: request.languageCode)
        let chunks = SpeechTextChunker().chunks(
            text: request.text,
            startingAt: request.characterOffset,
            maximumLength: 2_000
        )

        for chunk in chunks {
            let utterance = AVSpeechUtterance(string: chunk.text)
            utterance.voice = voice
            utterance.rate = appleSpeechRate(multiplier: request.rateMultiplier)
            contexts[ObjectIdentifier(utterance)] = UtteranceContext(
                generation: activeGeneration,
                chapterID: request.chapterID,
                baseOffset: chunk.utf16Offset,
                totalCharacterCount: request.text.utf16.count
            )
            synthesizer.speak(utterance)
        }
        updateSystemMediaState()
        onStateChanged?(.playing)
    }

    public func pause() {
        if synthesizer.pauseSpeaking(at: .word) {
            isPaused = true
            updateSystemMediaState()
            onStateChanged?(.paused)
        }
    }

    public func resume() {
        guard let activeRequest else { return }
        let endOffset = activeRequest.text.utf16.count
        let resumeOffset = currentOffset >= endOffset ? 0 : currentOffset
        play(activeRequest.withOffset(resumeOffset))
    }

    public func stop() {
        generation = UUID()
        contexts.removeAll()
        synthesizer.stopSpeaking(at: .immediate)
        activeRequest = nil
        currentOffset = 0
        isPaused = false
        mediaController.clear()
        onStateChanged?(.stopped)
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

    public nonisolated func speechSynthesizer(
        _ synthesizer: AVSpeechSynthesizer,
        willSpeakRangeOfSpeechString characterRange: NSRange,
        utterance: AVSpeechUtterance
    ) {
        let utteranceID = ObjectIdentifier(utterance)
        Task { @MainActor [weak self] in
            guard let self,
                  let context = self.contexts[utteranceID],
                  context.generation == self.generation else { return }
            self.currentOffset = context.baseOffset + characterRange.location
            self.updateSystemMediaState()
            self.onProgress?(
                SpeechPlaybackProgress(
                    chapterID: context.chapterID,
                    characterOffset: self.currentOffset,
                    totalCharacterCount: context.totalCharacterCount
                )
            )
        }
    }

    public nonisolated func speechSynthesizer(
        _ synthesizer: AVSpeechSynthesizer,
        didFinish utterance: AVSpeechUtterance
    ) {
        let utteranceID = ObjectIdentifier(utterance)
        Task { @MainActor [weak self] in
            guard let self,
                  let context = self.contexts.removeValue(forKey: utteranceID),
                  context.generation == self.generation else { return }
            let hasPendingUtterances = self.contexts.values.contains { $0.generation == context.generation }
            guard !hasPendingUtterances else { return }
            self.currentOffset = context.totalCharacterCount
            self.isPaused = true
            self.updateSystemMediaState()
            self.onProgress?(
                SpeechPlaybackProgress(
                    chapterID: context.chapterID,
                    characterOffset: context.totalCharacterCount,
                    totalCharacterCount: context.totalCharacterCount
                )
            )
            self.onStateChanged?(.stopped)
            try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
            self.onFinished?()
        }
    }

    public nonisolated func speechSynthesizer(
        _ synthesizer: AVSpeechSynthesizer,
        didCancel utterance: AVSpeechUtterance
    ) {
        let utteranceID = ObjectIdentifier(utterance)
        Task { @MainActor [weak self] in
            self?.contexts.removeValue(forKey: utteranceID)
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
        let duration = Double(activeRequest.text.utf16.count) / 14
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
