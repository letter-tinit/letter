import Foundation

@MainActor
protocol AudioBookPlaybackUseCase: AnyObject {
    var onProgress: ((SpeechPlaybackProgress) -> Void)? { get set }
    var onFinished: (() -> Void)? { get set }
    var onStateChanged: ((SpeechPlaybackState) -> Void)? { get set }

    func availableVoices() -> [SpeechVoice]
    func play(
        bookTitle: String,
        chapter: BookChapter,
        from characterOffset: Int,
        rate: Double,
        voiceID: String?
    ) throws
    func pause()
    func resume()
    func stop()
}

@MainActor
final class DefaultAudioBookPlaybackUseCase: AudioBookPlaybackUseCase {
    private let engine: any SpeechPlaybackEngine

    init(engine: any SpeechPlaybackEngine) {
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

    func availableVoices() -> [SpeechVoice] {
        engine.availableVoices().sorted {
            if $0.quality != $1.quality { return $0.quality > $1.quality }
            return $0.name < $1.name
        }
    }

    func play(
        bookTitle: String,
        chapter: BookChapter,
        from characterOffset: Int,
        rate: Double,
        voiceID: String?
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
                voiceID: voiceID
            )
        )
    }

    func pause() { engine.pause() }
    func resume() { engine.resume() }
    func stop() { engine.stop() }
}
