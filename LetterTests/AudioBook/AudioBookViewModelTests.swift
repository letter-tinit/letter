import Foundation
import Testing
@testable import Letter

@MainActor
struct AudioBookViewModelTests {
    @Test
    func automaticallyStartsNextChapterAfterFinishing() {
        let fixture = makeFixture()

        fixture.viewModel.prepareChapter(
            bookID: fixture.book.id,
            chapterID: fixture.book.chapters[0].id
        )
        fixture.viewModel.play()
        fixture.playback.finishCurrentChapter()

        #expect(fixture.viewModel.activeChapterID == fixture.book.chapters[1].id)
        #expect(fixture.playback.playedChapters == fixture.book.chapters.map(\.id))
    }

    @Test
    func disablingAutomaticAdvanceKeepsFinishedChapterSelected() {
        let fixture = makeFixture()
        fixture.viewModel.automaticallyPlaysNextChapter = false

        fixture.viewModel.prepareChapter(
            bookID: fixture.book.id,
            chapterID: fixture.book.chapters[0].id
        )
        fixture.viewModel.play()
        fixture.playback.finishCurrentChapter()

        #expect(fixture.viewModel.activeChapterID == fixture.book.chapters[0].id)
        #expect(fixture.playback.playedChapters == [fixture.book.chapters[0].id])
    }

    @Test
    func movingChapterWhilePausedDoesNotStartPlayback() {
        let fixture = makeFixture()

        fixture.viewModel.prepareChapter(
            bookID: fixture.book.id,
            chapterID: fixture.book.chapters[0].id
        )
        fixture.viewModel.play()
        fixture.viewModel.pause()
        fixture.viewModel.moveToNextChapter()

        #expect(fixture.viewModel.activeChapterID == fixture.book.chapters[1].id)
        #expect(fixture.playback.playedChapters == [fixture.book.chapters[0].id])
        #expect(!fixture.viewModel.canMoveToNextChapter)
        #expect(fixture.viewModel.canMoveToPreviousChapter)
    }

    @Test
    func remoteNextCommandStartsTheNextChapter() {
        let fixture = makeFixture()

        fixture.viewModel.prepareChapter(
            bookID: fixture.book.id,
            chapterID: fixture.book.chapters[0].id
        )
        fixture.viewModel.play()
        fixture.playback.requestNextChapter()

        #expect(fixture.viewModel.activeChapterID == fixture.book.chapters[1].id)
        #expect(fixture.playback.playedChapters == fixture.book.chapters.map(\.id))
        #expect(fixture.playback.navigationAvailability == (true, false))
    }

    @Test
    func passesEnglishBookLanguageToAutomaticVoicePlayback() {
        let chapter = BookChapter(title: "One", content: "English content", index: 0)
        let book = Book(
            title: "English Book",
            format: .epub,
            chapters: [chapter],
            language: .english
        )
        let playback = FakeAudioBookPlaybackUseCase()
        let viewModel = AudioBookViewModel(
            libraryUseCase: StubBookLibraryUseCase(book: book),
            playbackUseCase: playback
        )

        viewModel.prepareChapter(bookID: book.id, chapterID: chapter.id)
        viewModel.play()

        #expect(playback.playedLanguages == [.english])
    }

    private func makeFixture() -> ViewModelFixture {
        let chapters = [
            BookChapter(title: "One", content: "First chapter", index: 0),
            BookChapter(title: "Two", content: "Second chapter", index: 1)
        ]
        let book = Book(title: "Book", format: .epub, chapters: chapters)
        let playback = FakeAudioBookPlaybackUseCase()
        let viewModel = AudioBookViewModel(
            libraryUseCase: StubBookLibraryUseCase(book: book),
            playbackUseCase: playback
        )
        return ViewModelFixture(book: book, playback: playback, viewModel: viewModel)
    }
}

@MainActor
private struct ViewModelFixture {
    let book: Book
    let playback: FakeAudioBookPlaybackUseCase
    let viewModel: AudioBookViewModel
}

@MainActor
private final class StubBookLibraryUseCase: BookLibraryUseCase {
    let book: Book

    init(book: Book) {
        self.book = book
    }

    func loadBooks() throws -> [Book] { [book] }
    func importBook(from url: URL) throws -> Book { book }
    func importBook(from url: URL) async throws -> Book { book }
    func deleteBook(id: UUID) throws {}
    func savePosition(bookID: UUID, chapterID: UUID, characterOffset: Int) throws {}
}

@MainActor
private final class FakeAudioBookPlaybackUseCase: AudioBookPlaybackUseCase {
    var onProgress: ((SpeechPlaybackProgress) -> Void)?
    var onFinished: (() -> Void)?
    var onStateChanged: ((SpeechPlaybackState) -> Void)?
    var onPreviousChapterRequested: (() -> Void)?
    var onNextChapterRequested: (() -> Void)?
    private(set) var playedChapters: [UUID] = []
    private(set) var playedLanguages: [BookLanguage] = []
    private(set) var navigationAvailability = (false, false)
    private var currentChapter: BookChapter?
    func play(
        bookTitle: String,
        chapter: BookChapter,
        from characterOffset: Int,
        rate: Double,
        language: BookLanguage
    ) throws {
        currentChapter = chapter
        playedChapters.append(chapter.id)
        playedLanguages.append(language)
        onStateChanged?(.playing)
    }

    func pause() { onStateChanged?(.paused) }
    func resume() { onStateChanged?(.playing) }
    func stop() { onStateChanged?(.stopped) }
    func setChapterNavigation(previousEnabled: Bool, nextEnabled: Bool) {
        navigationAvailability = (previousEnabled, nextEnabled)
    }

    func requestNextChapter() {
        onNextChapterRequested?()
    }

    func finishCurrentChapter() {
        guard let currentChapter else { return }
        onProgress?(
            SpeechPlaybackProgress(
                chapterID: currentChapter.id,
                characterOffset: currentChapter.characterCount,
                totalCharacterCount: currentChapter.characterCount
            )
        )
        onStateChanged?(.stopped)
        onFinished?()
    }
}
