import Foundation
import Utility

@MainActor
public protocol AudioBookPlaybackUseCase: AnyObject {
    var onProgress: ((SpeechPlaybackProgress) -> Void)? { get set }
    var onFinished: (() -> Void)? { get set }
    var onStateChanged: ((SpeechPlaybackState) -> Void)? { get set }
    var onPreviousChapterRequested: (() -> Void)? { get set }
    var onNextChapterRequested: (() -> Void)? { get set }
    var onFailure: ((SpeechPlaybackFailure) -> Void)? { get set }

    func play(
        bookTitle: String,
        chapter: BookChapter,
        from characterOffset: Int,
        rate: Double,
        language: BookLanguage
    ) throws
    func pause()
    func resume()
    func stop()
    func skip(seconds: TimeInterval)
    func setChapterNavigation(previousEnabled: Bool, nextEnabled: Bool)
    func normalizedRate(_ rate: Double) -> Double
    func characterOffset(for fraction: Double, in chapter: BookChapter) -> Int
    func skippedCharacterOffset(
        currentOffset: Int,
        seconds: TimeInterval,
        rate: Double,
        in chapter: BookChapter
    ) -> Int
}

@MainActor
public final class ImpAudioBookPlaybackUseCase: AudioBookPlaybackUseCase {
    private let settings: any SpeechProviderSettingsRepository
    private let media: any SystemMediaRepository
    private let appleEngine: any SpeechPlaybackRepository
    private let googleEngine: any SpeechPlaybackRepository
    private let offlineEngine: any SpeechPlaybackRepository
    private var engine: any SpeechPlaybackRepository
    private var activeRequest: SpeechPlaybackRequest?
    private var currentOffset = 0
    private var state: SpeechPlaybackState = .stopped

    public var onProgress: ((SpeechPlaybackProgress) -> Void)?
    public var onFinished: (() -> Void)?
    public var onStateChanged: ((SpeechPlaybackState) -> Void)?
    public var onPreviousChapterRequested: (() -> Void)?
    public var onNextChapterRequested: (() -> Void)?
    public var onFailure: ((SpeechPlaybackFailure) -> Void)?

    public init(
        settings: any SpeechProviderSettingsRepository,
        media: any SystemMediaRepository,
        appleEngine: any SpeechPlaybackRepository,
        googleEngine: any SpeechPlaybackRepository,
        offlineEngine: any SpeechPlaybackRepository
    ) {
        self.settings = settings
        self.media = media
        self.appleEngine = appleEngine
        self.googleEngine = googleEngine
        self.offlineEngine = offlineEngine
        engine = appleEngine
        bindEngine()
        bindMedia()
    }

    public func play(
        bookTitle: String,
        chapter: BookChapter,
        from characterOffset: Int,
        rate: Double,
        language: BookLanguage
    ) throws {
        guard !chapter.content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw AudioBookError.emptyBook
        }
        let selection = selectedSpeech(for: language)
        let request = SpeechPlaybackRequest(
            bookTitle: bookTitle, chapterTitle: chapter.title, chapterID: chapter.id,
            text: chapter.content,
            characterOffset: min(max(characterOffset, 0), chapter.characterCount),
            rateMultiplier: min(max(rate, 0.5), 3),
            languageCode: language.languageCode, selection: selection
        )
        activate(engine(for: selection))
        start(request)
    }

    public func pause() { engine.pause() }
    public func resume() { engine.resume() }
    public func skip(seconds: TimeInterval) { engine.skip(seconds: seconds) }

    public func stop() {
        activeRequest = nil
        currentOffset = 0
        state = .stopped
        engine.stop()
        media.clear()
    }

    public func setChapterNavigation(previousEnabled: Bool, nextEnabled: Bool) {
        media.setChapterNavigation(previousEnabled: previousEnabled, nextEnabled: nextEnabled)
    }

    public func normalizedRate(_ rate: Double) -> Double {
        (min(max(rate, 0.5), 3) * 4).rounded() / 4
    }

    public func characterOffset(for fraction: Double, in chapter: BookChapter) -> Int {
        Int(Double(chapter.characterCount) * min(max(fraction, 0), 1))
    }

    public func skippedCharacterOffset(
        currentOffset: Int, seconds: TimeInterval, rate: Double, in chapter: BookChapter
    ) -> Int {
        SpeechPlaybackTiming(characterCount: chapter.characterCount, rate: normalizedRate(rate))
            .skippedOffset(from: currentOffset, seconds: seconds)
    }

    private func selectedSpeech(for language: BookLanguage) -> SpeechSelection {
        switch settings.loadProvider() {
        case .apple:
            return .apple(voiceID: settings.loadAppleVoiceID(for: language))
        case .googleCloud:
            return .googleCloud(voice: settings.loadGoogleCloudVoice(for: language))
        case .offline:
            let model = settings.loadOfflineModel(for: language)
            return .offline(model: model, voice: settings.loadOfflineVoice(for: model) ?? model.defaultVoice)
        }
    }

    private func engine(for selection: SpeechSelection) -> any SpeechPlaybackRepository {
        switch selection {
        case .apple: appleEngine
        case .googleCloud: googleEngine
        case .offline: offlineEngine
        }
    }

    private func activate(_ next: any SpeechPlaybackRepository) {
        guard ObjectIdentifier(engine) != ObjectIdentifier(next) else { return }
        engine.onProgress = nil
        engine.onFinished = nil
        engine.onStateChanged = nil
        engine.onFailure = nil
        engine.stop()
        engine = next
        bindEngine()
    }

    private func start(_ request: SpeechPlaybackRequest) {
        activeRequest = request
        currentOffset = request.characterOffset
        engine.play(request)
    }

    private func bindEngine() {
        engine.onProgress = { [weak self] progress in
            guard let self, activeRequest?.chapterID == progress.chapterID else { return }
            currentOffset = progress.characterOffset
            publishMedia()
            onProgress?(progress)
        }
        engine.onStateChanged = { [weak self] state in
            guard let self else { return }
            self.state = state
            publishMedia()
            onStateChanged?(state)
        }
        engine.onFinished = { [weak self] in
            guard let self else { return }
            state = .paused
            publishMedia()
            onFinished?()
        }
        engine.onFailure = { [weak self] failure in
            self?.handleFailure(failure)
        }
    }

    private func handleFailure(_ failure: SpeechPlaybackFailure) {
        let failedRequest = activeRequest
        onFailure?(failure)
        guard let request = failedRequest, activeRequest == request,
              ObjectIdentifier(engine) != ObjectIdentifier(appleEngine) else { return }
        let language = BookLanguage(languageCode: request.languageCode)
        let voiceID = language.flatMap { settings.loadAppleVoiceID(for: $0) }
        activate(appleEngine)
        start(request.withOffset(currentOffset, selection: .apple(voiceID: voiceID)))
    }

    private func bindMedia() {
        media.onPlay = { [weak self] in self?.resume() }
        media.onPause = { [weak self] in self?.pause() }
        media.onToggle = { [weak self] in
            guard let self else { return }
            state == .playing ? pause() : resume()
        }
        media.onSkip = { [weak self] in self?.skip(seconds: $0) }
        media.onSeekToTime = { [weak self] in self?.seek(to: $0) }
        media.onPreviousChapter = { [weak self] in self?.onPreviousChapterRequested?() }
        media.onNextChapter = { [weak self] in self?.onNextChapterRequested?() }
    }

    private func seek(to time: TimeInterval) {
        guard let request = activeRequest else { return }
        let timing = SpeechPlaybackTiming(
            characterCount: request.text.utf16.count, rate: request.rateMultiplier
        )
        guard timing.duration > 0 else { return }
        start(request.withOffset(timing.characterOffset(at: time)))
    }

    private func publishMedia() {
        guard let request = activeRequest else { return }
        let timing = SpeechPlaybackTiming(
            characterCount: request.text.utf16.count, rate: request.rateMultiplier
        )
        media.update(SystemMediaState(
            title: request.chapterTitle, bookTitle: request.bookTitle,
            identifier: request.chapterID.uuidString,
            duration: timing.duration, elapsedTime: timing.elapsedTime(at: currentOffset),
            // Retain the completed/failed chapter on the lock screen until explicit stop.
            playbackState: state == .playing ? .playing : .paused
        ))
    }
}
