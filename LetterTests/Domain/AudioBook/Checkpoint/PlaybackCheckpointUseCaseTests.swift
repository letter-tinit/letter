import XCTest
@testable import Domain

@MainActor
final class PlaybackCheckpointUseCaseTests: XCTestCase {
    func test_restorePosition_usesSavedCheckpointAndRollsBackResumeOffset() throws {
        let chapter = AudioBookTestFactory.chapter(
            content: "Start. Middle sentence has enough words for rollback testing. End.",
            index: 0
        )
        let book = AudioBookTestFactory.book(chapters: [chapter])
        let checkpoint = BookPlaybackCheckpoint(
            position: BookReadingPosition(chapterID: chapter.id, characterOffset: 40),
            rateMultiplier: 1,
            furthestPosition: BookReadingPosition(chapterID: chapter.id, characterOffset: 50)
        )
        let useCase = ImpPlaybackCheckpointUseCase(
            repository: FakePlaybackCheckpointRepository(checkpoints: [book.id: checkpoint])
        )

        let restored = try useCase.restorePosition(in: book)

        XCTAssertEqual(restored.lastPosition?.chapterID, chapter.id)
        XCTAssertLessThan(restored.lastPosition?.characterOffset ?? 999, 40)
        XCTAssertEqual(restored.furthestPosition?.characterOffset, 50)
    }

    func test_savedReadingRate_clampsInvalidStoredRate() throws {
        let bookID = UUID()
        let checkpoint = BookPlaybackCheckpoint(
            position: BookReadingPosition(chapterID: UUID(), characterOffset: 0),
            rateMultiplier: 10
        )
        let useCase = ImpPlaybackCheckpointUseCase(
            repository: FakePlaybackCheckpointRepository(checkpoints: [bookID: checkpoint])
        )

        let rate = try useCase.savedReadingRate(for: bookID)

        XCTAssertEqual(rate, 3)
    }

    func test_recordProgress_clampsOffsetAndRateThenPersistsWhenForced() throws {
        let chapter = AudioBookTestFactory.chapter(content: "Hello world", index: 0)
        let book = AudioBookTestFactory.book(chapters: [chapter])
        let repository = FakePlaybackCheckpointRepository()
        let useCase = ImpPlaybackCheckpointUseCase(repository: repository)

        let checkpoint = try useCase.recordProgress(
            in: book,
            chapterID: chapter.id,
            characterOffset: 999,
            rateMultiplier: 9,
            force: true
        )

        XCTAssertEqual(checkpoint.position.characterOffset, chapter.characterCount)
        XCTAssertEqual(checkpoint.rateMultiplier, 3)
        XCTAssertEqual(repository.savedCheckpoints.first?.checkpoint, checkpoint)
    }

    func test_recordProgress_skipsPersistenceWhenDistanceIsTooSmallAndNotForced() throws {
        let chapter = AudioBookTestFactory.chapter(content: String(repeating: "a", count: 100), index: 0)
        let book = AudioBookTestFactory.book(chapters: [chapter])
        let saved = BookPlaybackCheckpoint(
            position: BookReadingPosition(chapterID: chapter.id, characterOffset: 10),
            rateMultiplier: 1
        )
        let repository = FakePlaybackCheckpointRepository(checkpoints: [book.id: saved])
        let useCase = ImpPlaybackCheckpointUseCase(repository: repository)

        let checkpoint = try useCase.recordProgress(
            in: book,
            chapterID: chapter.id,
            characterOffset: 11,
            rateMultiplier: 1,
            force: false
        )

        XCTAssertEqual(checkpoint.position.characterOffset, 11)
        XCTAssertTrue(repository.savedCheckpoints.isEmpty)
    }
}
