import Foundation
import Utility

@MainActor
public protocol AudioBookPlaybackUseCase: AnyObject {
    var onProgress: ((SpeechPlaybackProgress) -> Void)? { get set }
    var onFinished: (() -> Void)? { get set }
    var onStateChanged: ((SpeechPlaybackState) -> Void)? { get set }
    var onPreviousChapterRequested: (() -> Void)? { get set }
    var onNextChapterRequested: (() -> Void)? { get set }

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
    func setChapterNavigation(previousEnabled: Bool, nextEnabled: Bool)
}

@MainActor
public final class ImpAudioBookPlaybackUseCase: AudioBookPlaybackUseCase {
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

    public func setChapterNavigation(previousEnabled: Bool, nextEnabled: Bool) {
        engine.setChapterNavigation(
            previousEnabled: previousEnabled,
            nextEnabled: nextEnabled
        )
    }
}
