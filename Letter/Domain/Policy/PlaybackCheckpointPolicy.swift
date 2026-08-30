import Foundation

struct PlaybackCheckpointPolicy: Sendable {
    private let estimatedCharactersPerSecond: Double
    private let persistenceInterval: TimeInterval
    private let resumeRollback: TimeInterval
    private let maximumAdditionalRollback: TimeInterval

    init(
        estimatedCharactersPerSecond: Double = 14,
        persistenceInterval: TimeInterval = 3,
        resumeRollback: TimeInterval = 5,
        maximumAdditionalRollback: TimeInterval = 2
    ) {
        self.estimatedCharactersPerSecond = estimatedCharactersPerSecond
        self.persistenceInterval = persistenceInterval
        self.resumeRollback = resumeRollback
        self.maximumAdditionalRollback = maximumAdditionalRollback
    }

    func shouldPersist(
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

    func resumePosition(
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

    func furthestPosition(
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
