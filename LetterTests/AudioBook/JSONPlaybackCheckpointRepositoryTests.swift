import Foundation
import Testing
@testable import Letter

@MainActor
struct JSONPlaybackCheckpointRepositoryTests {
    @Test
    func reloadsCheckpointFromDiskAfterRepositoryIsRecreated() throws {
        let storageURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("letter-checkpoint-\(UUID().uuidString).json")
        defer { try? FileManager.default.removeItem(at: storageURL) }
        let bookID = UUID()
        let checkpoint = BookPlaybackCheckpoint(
            position: BookReadingPosition(chapterID: UUID(), characterOffset: 527),
            rateMultiplier: 1.25
        )
        let writer = JSONPlaybackCheckpointRepository(storageURL: storageURL)
        try writer.save(checkpoint, for: bookID)

        let reader = JSONPlaybackCheckpointRepository(storageURL: storageURL)

        #expect(try reader.checkpoint(for: bookID) == checkpoint)
    }

    @Test
    func decodesCheckpointCreatedBeforeFurthestPositionWasAdded() throws {
        let chapterID = UUID()
        let json = """
        {
          "position": {
            "chapterID": "\(chapterID.uuidString)",
            "characterOffset": 123
          },
          "rateMultiplier": 1.25
        }
        """

        let checkpoint = try JSONDecoder().decode(
            BookPlaybackCheckpoint.self,
            from: Data(json.utf8)
        )

        #expect(checkpoint.position.chapterID == chapterID)
        #expect(checkpoint.position.characterOffset == 123)
        #expect(checkpoint.furthestPosition == nil)
    }
}
