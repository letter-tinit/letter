import Foundation

@MainActor
protocol PlaybackCheckpointRepository: AnyObject {
    func checkpoint(for bookID: UUID) throws -> BookPlaybackCheckpoint?
    func save(_ checkpoint: BookPlaybackCheckpoint, for bookID: UUID) throws
    func deleteCheckpoint(for bookID: UUID) throws
}

@MainActor
protocol PlaybackCheckpointUseCase: AnyObject {
    func restorePosition(in book: Book) throws -> Book
    func recordProgress(
        in book: Book,
        chapterID: UUID,
        characterOffset: Int,
        rateMultiplier: Double,
        force: Bool
    ) throws -> BookPlaybackCheckpoint
    func deleteCheckpoint(for bookID: UUID) throws
}

@MainActor
final class DefaultPlaybackCheckpointUseCase: PlaybackCheckpointUseCase {
    private let repository: any PlaybackCheckpointRepository
    private let policy: PlaybackCheckpointPolicy

    init(
        repository: any PlaybackCheckpointRepository,
        policy: PlaybackCheckpointPolicy? = nil
    ) {
        self.repository = repository
        self.policy = policy ?? PlaybackCheckpointPolicy()
    }

    func restorePosition(in book: Book) throws -> Book {
        let checkpoint = try repository.checkpoint(for: book.id)
            ?? book.lastPosition.map {
                BookPlaybackCheckpoint(
                    position: $0,
                    rateMultiplier: 1,
                    furthestPosition: book.furthestPosition ?? $0
                )
            }
        guard let checkpoint,
              let chapter = book.chapters.first(where: {
                  $0.id == checkpoint.position.chapterID
              }) else { return book }
        var restored = book
        let position = policy.resumePosition(from: checkpoint, in: chapter)
        restored.updatePlaybackPosition(
            chapterID: position.chapterID,
            characterOffset: position.characterOffset
        )
        let furthest = checkpoint.furthestPosition ?? checkpoint.position
        restored.updateFurthestPosition(
            chapterID: furthest.chapterID,
            characterOffset: furthest.characterOffset
        )
        return restored
    }

    func recordProgress(
        in book: Book,
        chapterID: UUID,
        characterOffset: Int,
        rateMultiplier: Double,
        force: Bool = false
    ) throws -> BookPlaybackCheckpoint {
        guard let chapter = book.chapters.first(where: { $0.id == chapterID }) else {
            throw AudioBookError.chapterNotFound
        }
        let saved = try repository.checkpoint(for: book.id)
        let position = BookReadingPosition(
            chapterID: chapterID,
            characterOffset: min(max(characterOffset, 0), chapter.characterCount)
        )
        let previousFurthest = saved?.furthestPosition
            ?? saved?.position
            ?? book.furthestPosition
            ?? book.lastPosition
        let checkpoint = BookPlaybackCheckpoint(
            position: position,
            rateMultiplier: min(max(rateMultiplier, 0.5), 3),
            furthestPosition: policy.furthestPosition(
                current: previousFurthest,
                candidate: position,
                in: book
            )
        )
        guard saved != checkpoint else { return checkpoint }
        guard force || policy.shouldPersist(
            saved: saved,
            chapterID: chapterID,
            characterOffset: characterOffset,
            rateMultiplier: rateMultiplier
        ) else { return checkpoint }
        try repository.save(checkpoint, for: book.id)
        return checkpoint
    }

    func deleteCheckpoint(for bookID: UUID) throws {
        try repository.deleteCheckpoint(for: bookID)
    }
}
