import Foundation
import Testing
@testable import Letter

struct PlaybackCheckpointPolicyTests {
    @Test
    func persistsAfterApproximatelyFiveSecondsOfReading() {
        let chapterID = UUID()
        let policy = PlaybackCheckpointPolicy(
            estimatedCharactersPerSecond: 10,
            persistenceInterval: 5
        )
        let saved = BookPlaybackCheckpoint(
            position: BookReadingPosition(chapterID: chapterID, characterOffset: 100),
            rateMultiplier: 1
        )

        #expect(!policy.shouldPersist(
            saved: saved,
            chapterID: chapterID,
            characterOffset: 149,
            rateMultiplier: 1
        ))
        #expect(policy.shouldPersist(
            saved: saved,
            chapterID: chapterID,
            characterOffset: 150,
            rateMultiplier: 1
        ))
    }

    @Test
    func resumesAtNaturalBoundaryFiveToTenSecondsBeforeCheckpoint() {
        let chapterID = UUID()
        let content = String(repeating: "a", count: 110)
            + "."
            + String(repeating: "b", count: 189)
        let chapter = BookChapter(
            id: chapterID,
            title: "Chapter",
            content: content,
            index: 0
        )
        let checkpoint = BookPlaybackCheckpoint(
            position: BookReadingPosition(chapterID: chapterID, characterOffset: 200),
            rateMultiplier: 1
        )

        let position = PlaybackCheckpointPolicy().resumePosition(
            from: checkpoint,
            in: chapter
        )

        #expect(position.characterOffset == 111)
    }

    @Test
    func completedChapterRemainsCompleted() {
        let chapter = BookChapter(title: "Chapter", content: "Finished text", index: 0)
        let checkpoint = BookPlaybackCheckpoint(
            position: BookReadingPosition(
                chapterID: chapter.id,
                characterOffset: chapter.characterCount
            ),
            rateMultiplier: 1
        )

        let position = PlaybackCheckpointPolicy().resumePosition(
            from: checkpoint,
            in: chapter
        )

        #expect(position.characterOffset == chapter.characterCount)
    }
}
