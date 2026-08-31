import Foundation
import Domain
import Utility

@MainActor
public final class ImpPlaybackCheckpointRepository: PlaybackCheckpointRepository {
    private struct Record: Codable {
        let bookID: UUID
        let checkpoint: BookPlaybackCheckpoint
    }

    private var checkpoints: [UUID: BookPlaybackCheckpoint]
    private let storageURL: URL?

    public init(inMemory: Bool = false, storageURL: URL? = nil) {
        if inMemory {
            self.storageURL = nil
            checkpoints = [:]
            return
        }
        let resolvedURL = storageURL ?? Self.defaultStorageURL()
        self.storageURL = resolvedURL
        checkpoints = Self.load(from: resolvedURL)
    }

    public func checkpoint(for bookID: UUID) throws -> BookPlaybackCheckpoint? {
        checkpoints[bookID]
    }

    public func save(_ checkpoint: BookPlaybackCheckpoint, for bookID: UUID) throws {
        var updated = checkpoints
        updated[bookID] = checkpoint
        try commit(updated)
    }

    public func deleteCheckpoint(for bookID: UUID) throws {
        guard checkpoints[bookID] != nil else { return }
        var updated = checkpoints
        updated.removeValue(forKey: bookID)
        try commit(updated)
    }

    private func commit(_ updated: [UUID: BookPlaybackCheckpoint]) throws {
        if let storageURL {
            let records = updated.map { Record(bookID: $0.key, checkpoint: $0.value) }
            let data = try JSONEncoder().encode(records)
            try data.write(to: storageURL, options: .atomic)
        }
        checkpoints = updated
    }

    private static func load(from url: URL?) -> [UUID: BookPlaybackCheckpoint] {
        guard let url,
              let data = try? Data(contentsOf: url),
              let records = try? JSONDecoder().decode([Record].self, from: data) else { return [:] }
        return Dictionary(
            records.map { ($0.bookID, $0.checkpoint) },
            uniquingKeysWith: { _, latest in latest }
        )
    }

    private static func defaultStorageURL() -> URL? {
        let directory = try? FileManager.default.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )
        return directory?.appendingPathComponent("AudioBookCheckpoints.json")
    }
}
