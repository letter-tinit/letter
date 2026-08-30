import Foundation

@MainActor
protocol AudioBookPlaybackUseCase: AnyObject {
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
final class ImpAudioBookPlaybackUseCase: AudioBookPlaybackUseCase {
    private let engine: any SpeechPlaybackRepository

    init(engine: any SpeechPlaybackRepository) {
        self.engine = engine
    }

    var onProgress: ((SpeechPlaybackProgress) -> Void)? {
        get { engine.onProgress }
        set { engine.onProgress = newValue }
    }

    var onFinished: (() -> Void)? {
        get { engine.onFinished }
        set { engine.onFinished = newValue }
    }

    var onStateChanged: ((SpeechPlaybackState) -> Void)? {
        get { engine.onStateChanged }
        set { engine.onStateChanged = newValue }
    }

    var onPreviousChapterRequested: (() -> Void)? {
        get { engine.onPreviousChapterRequested }
        set { engine.onPreviousChapterRequested = newValue }
    }

    var onNextChapterRequested: (() -> Void)? {
        get { engine.onNextChapterRequested }
        set { engine.onNextChapterRequested = newValue }
    }

    func play(
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

    func pause() { engine.pause() }
    func resume() { engine.resume() }
    func stop() { engine.stop() }

    func setChapterNavigation(previousEnabled: Bool, nextEnabled: Bool) {
        engine.setChapterNavigation(
            previousEnabled: previousEnabled,
            nextEnabled: nextEnabled
        )
    }
}
