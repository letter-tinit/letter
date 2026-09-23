import Foundation
@testable import Domain

@MainActor
final class FakePlaybackCheckpointRepository: PlaybackCheckpointRepository {
    var checkpoints: [UUID: BookPlaybackCheckpoint]
    var savedCheckpoints: [(checkpoint: BookPlaybackCheckpoint, bookID: UUID)] = []
    var deletedBookIDs: [UUID] = []

    init(checkpoints: [UUID: BookPlaybackCheckpoint] = [:]) {
        self.checkpoints = checkpoints
    }

    func checkpoint(for bookID: UUID) throws -> BookPlaybackCheckpoint? {
        checkpoints[bookID]
    }

    func save(_ checkpoint: BookPlaybackCheckpoint, for bookID: UUID) throws {
        savedCheckpoints.append((checkpoint, bookID))
        checkpoints[bookID] = checkpoint
    }

    func deleteCheckpoint(for bookID: UUID) throws {
        deletedBookIDs.append(bookID)
        checkpoints[bookID] = nil
    }
}
