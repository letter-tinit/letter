import Foundation

@MainActor
protocol PlaybackCheckpointRepository: AnyObject {
    func checkpoint(for bookID: UUID) throws -> BookPlaybackCheckpoint?
    func save(_ checkpoint: BookPlaybackCheckpoint, for bookID: UUID) throws
    func deleteCheckpoint(for bookID: UUID) throws
}
