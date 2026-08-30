import Foundation
import Testing
@testable import Letter

@MainActor
struct PlaybackCheckpointUseCaseTests {
    @Test
    func throttlesRoutineProgressButAlwaysSavesForcedCheckpoint() throws {
        let repository = CheckpointRepositorySpy()
        let useCase = DefaultPlaybackCheckpointUseCase(
            repository: repository,
            policy: PlaybackCheckpointPolicy(
                estimatedCharactersPerSecond: 10,
                persistenceInterval: 5
            )
        )
        let bookID = UUID()
        let chapterID = UUID()
        let book = Book(
            id: bookID,
            title: "Book",
            format: .epub,
            chapters: [
                BookChapter(
                    id: chapterID,
                    title: "Chapter",
                    content: String(repeating: "a", count: 300),
                    index: 0
                )
            ]
        )

        _ = try useCase.recordProgress(
            in: book,
            chapterID: chapterID,
            characterOffset: 100,
            rateMultiplier: 1,
            force: true
        )
        _ = try useCase.recordProgress(
            in: book,
            chapterID: chapterID,
            characterOffset: 120,
            rateMultiplier: 1,
            force: false
        )
        #expect(repository.saveCount == 1)

        _ = try useCase.recordProgress(
            in: book,
            chapterID: chapterID,
            characterOffset: 120,
            rateMultiplier: 1,
            force: true
        )
        #expect(repository.saveCount == 2)
    }

    @Test
    func listeningToEarlierChapterDoesNotRegressFurthestPosition() throws {
        let repository = CheckpointRepositorySpy()
        let chapters = [
            BookChapter(title: "One", content: String(repeating: "a", count: 200), index: 0),
            BookChapter(title: "Two", content: String(repeating: "b", count: 200), index: 1)
        ]
        let book = Book(title: "Book", format: .epub, chapters: chapters)
        repository.values[book.id] = BookPlaybackCheckpoint(
            position: BookReadingPosition(chapterID: chapters[1].id, characterOffset: 80),
            rateMultiplier: 1,
            furthestPosition: BookReadingPosition(
                chapterID: chapters[1].id,
                characterOffset: 80
            )
        )
        let useCase = DefaultPlaybackCheckpointUseCase(repository: repository)

        let checkpoint = try useCase.recordProgress(
            in: book,
            chapterID: chapters[0].id,
            characterOffset: 40,
            rateMultiplier: 1,
            force: true
        )

        #expect(checkpoint.position.chapterID == chapters[0].id)
        #expect(checkpoint.furthestPosition?.chapterID == chapters[1].id)
        #expect(checkpoint.furthestPosition?.characterOffset == 80)
    }

    @Test
    func restoresBookFromDurableCheckpointWithRollback() throws {
        let repository = CheckpointRepositorySpy()
        let chapterID = UUID()
        let content = String(repeating: "a", count: 110)
            + "."
            + String(repeating: "b", count: 189)
        let book = Book(
            title: "Book",
            format: .epub,
            chapters: [
                BookChapter(
                    id: chapterID,
                    title: "Chapter",
                    content: content,
                    index: 0
                )
            ]
        )
        repository.values[book.id] = BookPlaybackCheckpoint(
            position: BookReadingPosition(chapterID: chapterID, characterOffset: 200),
            rateMultiplier: 1
        )
        let useCase = DefaultPlaybackCheckpointUseCase(repository: repository)

        let restored = try useCase.restorePosition(in: book)

        #expect(restored.lastPosition?.chapterID == chapterID)
        #expect(restored.lastPosition?.characterOffset == 111)
        #expect(repository.saveCount == 0)
    }
}

@MainActor
private final class CheckpointRepositorySpy: PlaybackCheckpointRepository {
    var values: [UUID: BookPlaybackCheckpoint] = [:]
    private(set) var saveCount = 0

    func checkpoint(for bookID: UUID) throws -> BookPlaybackCheckpoint? {
        values[bookID]
    }

    func save(_ checkpoint: BookPlaybackCheckpoint, for bookID: UUID) throws {
        values[bookID] = checkpoint
        saveCount += 1
    }

    func deleteCheckpoint(for bookID: UUID) throws {
        values.removeValue(forKey: bookID)
    }
}
