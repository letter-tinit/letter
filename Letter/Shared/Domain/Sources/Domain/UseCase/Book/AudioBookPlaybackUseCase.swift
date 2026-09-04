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
    private let estimatedCharactersPerSecond = 14.0
    private let engine: any SpeechPlaybackRepository

    public init(engine: any SpeechPlaybackRepository) {
        self.engine = engine
    }

    public var onProgress: ((SpeechPlaybackProgress) -> Void)? {
        get { engine.onProgress }
        set { engine.onProgress = newValue }
    }

    public var onFinished: (() -> Void)? {
        get { engine.onFinished }
        set { engine.onFinished = newValue }
    }

    public var onStateChanged: ((SpeechPlaybackState) -> Void)? {
        get { engine.onStateChanged }
        set { engine.onStateChanged = newValue }
    }

    public var onPreviousChapterRequested: (() -> Void)? {
        get { engine.onPreviousChapterRequested }
        set { engine.onPreviousChapterRequested = newValue }
    }

    public var onNextChapterRequested: (() -> Void)? {
        get { engine.onNextChapterRequested }
        set { engine.onNextChapterRequested = newValue }
    }

    public var onFailure: ((SpeechPlaybackFailure) -> Void)? {
        get { engine.onFailure }
        set { engine.onFailure = newValue }
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
        engine.play(
            SpeechPlaybackRequest(
                bookTitle: bookTitle,
                chapterTitle: chapter.title,
                chapterID: chapter.id,
                text: chapter.content,
                characterOffset: min(max(characterOffset, 0), chapter.characterCount),
                rateMultiplier: min(max(rate, 0.5), 3),
                languageCode: language.languageCode
            )
        )
    }

    public func pause() { engine.pause() }
    public func resume() { engine.resume() }
    public func stop() { engine.stop() }
    public func skip(seconds: TimeInterval) { engine.skip(seconds: seconds) }

    public func setChapterNavigation(previousEnabled: Bool, nextEnabled: Bool) {
        engine.setChapterNavigation(
            previousEnabled: previousEnabled,
            nextEnabled: nextEnabled
        )
    }

    public func normalizedRate(_ rate: Double) -> Double {
        let clamped = min(max(rate, 0.5), 3)
        return (clamped * 4).rounded() / 4
    }

    public func characterOffset(for fraction: Double, in chapter: BookChapter) -> Int {
        let clamped = min(max(fraction, 0), 1)
        return Int(Double(chapter.characterCount) * clamped)
    }

    public func skippedCharacterOffset(
        currentOffset: Int,
        seconds: TimeInterval,
        rate: Double,
        in chapter: BookChapter
    ) -> Int {
        let delta = Int(seconds * estimatedCharactersPerSecond * normalizedRate(rate))
        return min(max(currentOffset + delta, 0), chapter.characterCount)
    }
}
