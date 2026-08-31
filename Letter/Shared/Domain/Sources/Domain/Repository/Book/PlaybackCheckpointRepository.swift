import Foundation
import Utility

@MainActor
public protocol PlaybackCheckpointRepository: AnyObject {
    func checkpoint(for bookID: UUID) throws -> BookPlaybackCheckpoint?
    func save(_ checkpoint: BookPlaybackCheckpoint, for bookID: UUID) throws
    func deleteCheckpoint(for bookID: UUID) throws
}
