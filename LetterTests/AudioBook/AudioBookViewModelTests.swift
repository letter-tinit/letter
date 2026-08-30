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
        let checkpoint = FakePlaybackCheckpointUseCase()
        let viewModel = AudioBookViewModel(
            libraryUseCase: StubBookLibraryUseCase(book: book),
            playbackUseCase: playback,
            exportUseCase: FakeAudioBookExportUseCase(),
            checkpointUseCase: checkpoint
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
        let checkpoint = FakePlaybackCheckpointUseCase()
        let viewModel = AudioBookViewModel(
            libraryUseCase: StubBookLibraryUseCase(book: book),
            playbackUseCase: playback,
            exportUseCase: FakeAudioBookExportUseCase(),
            checkpointUseCase: checkpoint
        )
        return ViewModelFixture(
            book: book,
            playback: playback,
            checkpoint: checkpoint,
            viewModel: viewModel
        )
    }

    @Test
    func remotePauseForcesLatestPositionToPersistentCheckpoint() {
        let fixture = makeFixture()
        let chapter = fixture.book.chapters[0]
        fixture.viewModel.prepareChapter(bookID: fixture.book.id, chapterID: chapter.id)
        fixture.viewModel.play()
        fixture.playback.reportProgress(characterOffset: 7)

        fixture.playback.pauseRemotely()

        #expect(fixture.checkpoint.lastPosition?.chapterID == chapter.id)
        #expect(fixture.checkpoint.lastPosition?.characterOffset == 7)
        #expect(fixture.checkpoint.lastRecordWasForced)
    }

    @Test
    func listeningToEarlierChapterPreservesFurthestProgressAndLaterOffset() {
        let fixture = makeFixture()
        let firstChapter = fixture.book.chapters[0]
        let secondChapter = fixture.book.chapters[1]
        fixture.viewModel.prepareChapter(
            bookID: fixture.book.id,
            chapterID: secondChapter.id
        )
        fixture.viewModel.play()
        fixture.playback.reportProgress(characterOffset: 7)
        let furthestProgress = fixture.viewModel.book(id: fixture.book.id)?.readingProgress

        fixture.viewModel.prepareChapter(
            bookID: fixture.book.id,
            chapterID: firstChapter.id
        )
        fixture.viewModel.play()
        fixture.playback.reportProgress(characterOffset: 5)

        #expect(fixture.viewModel.book(id: fixture.book.id)?.readingProgress == furthestProgress)
        fixture.viewModel.prepareChapter(
            bookID: fixture.book.id,
            chapterID: secondChapter.id
        )
        #expect(fixture.viewModel.currentCharacterOffset == 7)
    }
}

@MainActor
private struct ViewModelFixture {
    let book: Book
    let playback: FakeAudioBookPlaybackUseCase
    let checkpoint: FakePlaybackCheckpointUseCase
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
}

@MainActor
private final class FakePlaybackCheckpointUseCase: PlaybackCheckpointUseCase {
    private var checkpoint: BookPlaybackCheckpoint?
    private(set) var lastRecordWasForced = false
    var lastPosition: BookReadingPosition? { checkpoint?.position }

    func restorePosition(in book: Book) throws -> Book { book }

    func recordProgress(
        in book: Book,
        chapterID: UUID,
        characterOffset: Int,
        rateMultiplier: Double,
        force: Bool
    ) throws -> BookPlaybackCheckpoint {
        let position = BookReadingPosition(
            chapterID: chapterID,
            characterOffset: characterOffset
        )
        let furthest = PlaybackCheckpointPolicy().furthestPosition(
            current: checkpoint?.furthestPosition ?? book.furthestPosition,
            candidate: position,
            in: book
        )
        let updated = BookPlaybackCheckpoint(
            position: position,
            rateMultiplier: rateMultiplier,
            furthestPosition: furthest
        )
        checkpoint = updated
        lastRecordWasForced = force
        return updated
    }

    func deleteCheckpoint(for bookID: UUID) throws {}
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

    func reportProgress(characterOffset: Int) {
        guard let currentChapter else { return }
        onProgress?(
            SpeechPlaybackProgress(
                chapterID: currentChapter.id,
                characterOffset: characterOffset,
                totalCharacterCount: currentChapter.characterCount
            )
        )
    }

    func pauseRemotely() {
        onStateChanged?(.paused)
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

@MainActor
private final class FakeAudioBookExportUseCase: AudioBookExportUseCase {
    func export(
        book: Book,
        chapterIDs: Set<UUID>,
        rate: Double,
        onProgress: @escaping (Double) -> Void
    ) async throws -> URL {
        onProgress(1)
        return FileManager.default.temporaryDirectory.appendingPathComponent("test.m4a")
    }

    func cancel() {}
    func discardExport(at url: URL) {}
}
