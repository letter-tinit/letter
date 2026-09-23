import XCTest
@testable import Domain

@MainActor
final class AudioBookPlayerUseCaseTests: XCTestCase {
    func test_init_loadsBooksAndSavedReadingRates() {
        let book = AudioBookTestFactory.book()
        let checkpoint = BookPlaybackCheckpoint(
            position: BookReadingPosition(chapterID: book.chapters[0].id, characterOffset: 0),
            rateMultiplier: 1.75
        )
        let useCase = makeUseCase(
            books: [book],
            checkpoints: [book.id: checkpoint]
        ).useCase

        XCTAssertEqual(useCase.state.books.map(\.id), [book.id])
        XCTAssertEqual(useCase.state.savedReadingRates[book.id], 1.75)
    }

    func test_openChapterForViewing_restoresSavedOffsetAndPublishesNavigation() {
        let first = AudioBookTestFactory.chapter(content: String(repeating: "a", count: 100), index: 0)
        let second = AudioBookTestFactory.chapter(
            content: "Start. " + String(repeating: "b", count: 240),
            index: 1
        )
        let book = AudioBookTestFactory.book(
            chapters: [first, second],
            lastPosition: BookReadingPosition(chapterID: second.id, characterOffset: 150)
        )
        let harness = makeUseCase(books: [book])
        let restoredOffset = harness.useCase.state.books[0].lastPosition?.characterOffset ?? 0

        harness.useCase.openChapterForViewing(bookID: book.id, chapterID: second.id)

        XCTAssertEqual(harness.useCase.state.activeBookID, book.id)
        XCTAssertEqual(harness.useCase.state.activeChapterID, second.id)
        XCTAssertEqual(harness.useCase.state.currentCharacterOffset, restoredOffset)
        XCTAssertEqual(
            harness.useCase.state.playbackProgress,
            Double(restoredOffset) / Double(second.characterCount)
        )
        XCTAssertEqual(harness.playback.navigationUpdates.last?.previousEnabled, true)
        XCTAssertEqual(harness.playback.navigationUpdates.last?.nextEnabled, false)
        XCTAssertTrue(harness.playback.playRequests.isEmpty)
    }

    func test_togglePlayback_preparesSelectionAndStartsPlaybackWithSavedRate() {
        let chapter = AudioBookTestFactory.chapter(
            content: "Start. " + String(repeating: "a", count: 240),
            index: 0
        )
        let book = AudioBookTestFactory.book(chapters: [chapter], language: .english)
        let checkpoint = BookPlaybackCheckpoint(
            position: BookReadingPosition(chapterID: chapter.id, characterOffset: 150),
            rateMultiplier: 1.5
        )
        let harness = makeUseCase(
            books: [book],
            checkpoints: [book.id: checkpoint]
        )
        let restoredOffset = harness.useCase.state.books[0].lastPosition?.characterOffset ?? 0

        harness.useCase.togglePlayback(bookID: book.id, chapterID: chapter.id)

        XCTAssertEqual(harness.playback.playRequests.first?.bookTitle, book.title)
        XCTAssertEqual(harness.playback.playRequests.first?.chapter.id, chapter.id)
        XCTAssertEqual(harness.playback.playRequests.first?.characterOffset, restoredOffset)
        XCTAssertEqual(harness.playback.playRequests.first?.rate, 1.5)
        XCTAssertEqual(harness.playback.playRequests.first?.language, .english)
    }

    func test_playbackProgress_updatesStateAndPersistsCheckpoint() {
        let chapter = AudioBookTestFactory.chapter(content: String(repeating: "a", count: 100), index: 0)
        let book = AudioBookTestFactory.book(chapters: [chapter])
        let harness = makeUseCase(books: [book])

        harness.useCase.togglePlayback(bookID: book.id, chapterID: chapter.id)
        harness.playback.onStateChanged?(.playing)
        harness.playback.onProgress?(
            SpeechPlaybackProgress(
                chapterID: chapter.id,
                characterOffset: 55,
                totalCharacterCount: chapter.characterCount
            )
        )

        XCTAssertTrue(harness.useCase.state.isPlaying)
        XCTAssertFalse(harness.useCase.state.isPaused)
        XCTAssertEqual(harness.useCase.state.currentCharacterOffset, 55)
        XCTAssertEqual(harness.useCase.state.playbackProgress, 0.55)
        XCTAssertEqual(harness.checkpoints.savedCheckpoints.last?.bookID, book.id)
        XCTAssertEqual(harness.checkpoints.savedCheckpoints.last?.checkpoint.position.characterOffset, 55)
    }

    func test_seekWhilePaused_restartsPlaybackOnResumeInsteadOfResumingEngine() {
        let chapter = AudioBookTestFactory.chapter(content: String(repeating: "a", count: 100), index: 0)
        let book = AudioBookTestFactory.book(chapters: [chapter])
        let harness = makeUseCase(books: [book])

        harness.useCase.togglePlayback(bookID: book.id, chapterID: chapter.id)
        harness.playback.onStateChanged?(.paused)
        harness.useCase.seek(to: 0.7)
        harness.useCase.togglePlayback()

        XCTAssertEqual(harness.useCase.state.currentCharacterOffset, 70)
        XCTAssertEqual(harness.playback.resumeCount, 0)
        XCTAssertEqual(harness.playback.playRequests.last?.characterOffset, 70)
    }

    func test_finishedPlaybackAutomaticallyMovesToNextChapterAndStartsPlayback() {
        let first = AudioBookTestFactory.chapter(content: String(repeating: "a", count: 100), index: 0)
        let second = AudioBookTestFactory.chapter(content: String(repeating: "b", count: 90), index: 1)
        let book = AudioBookTestFactory.book(chapters: [first, second])
        let harness = makeUseCase(books: [book])

        harness.useCase.togglePlayback(bookID: book.id, chapterID: first.id)
        harness.playback.onStateChanged?(.playing)
        harness.playback.onFinished?()

        XCTAssertEqual(harness.useCase.state.activeChapterID, second.id)
        XCTAssertEqual(harness.useCase.state.currentCharacterOffset, 0)
        XCTAssertEqual(harness.playback.playRequests.last?.chapter.id, second.id)
        XCTAssertEqual(harness.playback.stopCount, 2)
    }

    private func makeUseCase(
        books: [Book],
        checkpoints: [UUID: BookPlaybackCheckpoint] = [:]
    ) -> (
        useCase: ImpAudioBookPlayerUseCase,
        playback: FakeAudioBookPlaybackUseCase,
        checkpoints: FakePlaybackCheckpointRepository
    ) {
        let checkpointRepository = FakePlaybackCheckpointRepository(checkpoints: checkpoints)
        let checkpointUseCase = ImpPlaybackCheckpointUseCase(repository: checkpointRepository)
        let libraryUseCase = ImpAudioBookUseCase(
            repository: FakeBookLibraryRepository(books: books),
            importer: FakeBookImportRepository(result: .success(books[0])),
            checkpointUseCase: checkpointUseCase
        )
        let playbackUseCase = FakeAudioBookPlaybackUseCase()
        let useCase = ImpAudioBookPlayerUseCase(
            libraryUseCase: libraryUseCase,
            playbackUseCase: playbackUseCase,
            checkpointUseCase: checkpointUseCase
        )
        return (useCase, playbackUseCase, checkpointRepository)
    }
}

@MainActor
private final class FakeAudioBookPlaybackUseCase: AudioBookPlaybackUseCase {
    struct PlayRequest {
        let bookTitle: String
        let chapter: BookChapter
        let characterOffset: Int
        let rate: Double
        let language: BookLanguage
    }

    var onProgress: ((SpeechPlaybackProgress) -> Void)?
    var onFinished: (() -> Void)?
    var onStateChanged: ((SpeechPlaybackState) -> Void)?
    var onPreviousChapterRequested: (() -> Void)?
    var onNextChapterRequested: (() -> Void)?
    var onFailure: ((SpeechPlaybackFailure) -> Void)?

    var playRequests: [PlayRequest] = []
    var pauseCount = 0
    var resumeCount = 0
    var stopCount = 0
    var skippedSeconds: [TimeInterval] = []
    var navigationUpdates: [(previousEnabled: Bool, nextEnabled: Bool)] = []

    func play(
        bookTitle: String,
        chapter: BookChapter,
        from characterOffset: Int,
        rate: Double,
        language: BookLanguage
    ) throws {
        playRequests.append(PlayRequest(
            bookTitle: bookTitle,
            chapter: chapter,
            characterOffset: characterOffset,
            rate: rate,
            language: language
        ))
    }

    func pause() {
        pauseCount += 1
    }

    func resume() {
        resumeCount += 1
    }

    func stop() {
        stopCount += 1
    }

    func skip(seconds: TimeInterval) {
        skippedSeconds.append(seconds)
    }

    func setChapterNavigation(previousEnabled: Bool, nextEnabled: Bool) {
        navigationUpdates.append((previousEnabled, nextEnabled))
    }

    func normalizedRate(_ rate: Double) -> Double {
        (min(max(rate, 0.5), 3) * 4).rounded() / 4
    }

    func characterOffset(for fraction: Double, in chapter: BookChapter) -> Int {
        Int(Double(chapter.characterCount) * min(max(fraction, 0), 1))
    }

    func skippedCharacterOffset(
        currentOffset: Int,
        seconds: TimeInterval,
        rate: Double,
        in chapter: BookChapter
    ) -> Int {
        min(max(currentOffset + Int(seconds * 10 * rate), 0), chapter.characterCount)
    }
}
