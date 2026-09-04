import Foundation
import Utility

@MainActor
public protocol PlaybackCheckpointUseCase: AnyObject {
    func restorePosition(in book: Book) throws -> Book
    func savedOffset(for chapterID: UUID, in book: Book) -> Int
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
public final class ImpPlaybackCheckpointUseCase: PlaybackCheckpointUseCase {
    private let repository: any PlaybackCheckpointRepository
    private let evaluator = PlaybackCheckpointEvaluator()

    public init(repository: any PlaybackCheckpointRepository) {
        self.repository = repository
    }

    public func restorePosition(in book: Book) throws -> Book {
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
        let position = evaluator.resumePosition(from: checkpoint, in: chapter)
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

    public func savedOffset(for chapterID: UUID, in book: Book) -> Int {
        if book.lastPosition?.chapterID == chapterID {
            return book.lastPosition?.characterOffset ?? 0
        }
        if book.furthestPosition?.chapterID == chapterID {
            return book.furthestPosition?.characterOffset ?? 0
        }
        return 0
    }

    public func recordProgress(
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
            furthestPosition: evaluator.furthestPosition(
                current: previousFurthest,
                candidate: position,
                in: book
            )
        )
        guard saved != checkpoint else { return checkpoint }
        guard force || evaluator.shouldPersist(
            saved: saved,
            chapterID: chapterID,
            characterOffset: characterOffset,
            rateMultiplier: rateMultiplier
        ) else { return checkpoint }
        try repository.save(checkpoint, for: book.id)
        return checkpoint
    }

    public func deleteCheckpoint(for bookID: UUID) throws {
        try repository.deleteCheckpoint(for: bookID)
    }
}

private struct PlaybackCheckpointEvaluator: Sendable {
    private let estimatedCharactersPerSecond: Double = 14
    private let persistenceInterval: TimeInterval = 3
    private let resumeRollback: TimeInterval = 5
    private let maximumAdditionalRollback: TimeInterval = 2

    public func shouldPersist(
        saved: BookPlaybackCheckpoint?,
        chapterID: UUID,
        characterOffset: Int,
        rateMultiplier: Double
    ) -> Bool {
        guard let saved else { return true }
        guard saved.position.chapterID == chapterID else { return true }
        guard characterOffset >= saved.position.characterOffset else { return true }
        return characterOffset - saved.position.characterOffset >= persistenceCharacterDistance(
            rateMultiplier: rateMultiplier
        )
    }

    public func resumePosition(
        from checkpoint: BookPlaybackCheckpoint,
        in chapter: BookChapter
    ) -> BookReadingPosition {
        let savedOffset = min(max(checkpoint.position.characterOffset, 0), chapter.characterCount)
        guard savedOffset > 0, savedOffset < chapter.characterCount else {
            return BookReadingPosition(chapterID: chapter.id, characterOffset: savedOffset)
        }
        let preferredOffset = max(
            savedOffset - characterDistance(
                seconds: resumeRollback,
                rateMultiplier: checkpoint.rateMultiplier
            ),
            0
        )
        let searchStart = max(
            preferredOffset - characterDistance(
                seconds: maximumAdditionalRollback,
                rateMultiplier: checkpoint.rateMultiplier
            ),
            0
        )
        let safeOffset = naturalBoundary(
            in: chapter.content,
            searchRange: searchStart..<preferredOffset,
            fallback: preferredOffset
        )
        return BookReadingPosition(chapterID: chapter.id, characterOffset: safeOffset)
    }

    public func furthestPosition(
        current: BookReadingPosition?,
        candidate: BookReadingPosition,
        in book: Book
    ) -> BookReadingPosition {
        guard let candidateIndex = book.chapters.firstIndex(where: {
            $0.id == candidate.chapterID
        }) else { return current ?? candidate }
        guard let current,
              let currentIndex = book.chapters.firstIndex(where: {
                  $0.id == current.chapterID
              }) else { return candidate }
        guard candidateIndex == currentIndex else {
            return candidateIndex > currentIndex ? candidate : current
        }
        return candidate.characterOffset > current.characterOffset ? candidate : current
    }

    private func persistenceCharacterDistance(rateMultiplier: Double) -> Int {
        characterDistance(seconds: persistenceInterval, rateMultiplier: rateMultiplier)
    }

    private func characterDistance(seconds: TimeInterval, rateMultiplier: Double) -> Int {
        let safeRate = min(max(rateMultiplier, 0.5), 3)
        return max(Int((estimatedCharactersPerSecond * seconds * safeRate).rounded()), 1)
    }

    private func naturalBoundary(
        in text: String,
        searchRange: Range<Int>,
        fallback: Int
    ) -> Int {
        let source = text as NSString
        let clampedFallback = min(max(fallback, 0), source.length)
        guard !searchRange.isEmpty else {
            return composedCharacterStart(clampedFallback, in: source)
        }
        let lowerBound = min(max(searchRange.lowerBound, 0), source.length)
        let range = NSRange(
            location: lowerBound,
            length: min(searchRange.count, source.length - lowerBound)
        )
        if let boundary = lastBoundary(in: source, characters: ".!?\n", range: range) {
            return boundary
        }
        if let boundary = lastBoundary(in: source, characters: " \t\n", range: range) {
            return boundary
        }
        return composedCharacterStart(clampedFallback, in: source)
    }

    private func lastBoundary(in source: NSString, characters: String, range: NSRange) -> Int? {
        let boundary = source.rangeOfCharacter(
            from: CharacterSet(charactersIn: characters),
            options: .backwards,
            range: range
        )
        guard boundary.location != NSNotFound else { return nil }
        return min(boundary.location + boundary.length, source.length)
    }

    private func composedCharacterStart(_ offset: Int, in source: NSString) -> Int {
        guard offset > 0, offset < source.length else { return offset }
        return source.rangeOfComposedCharacterSequence(at: offset).location
    }
}
