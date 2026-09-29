import Foundation
import XCTest
@testable import Data
@testable import Domain

@MainActor
final class ImpPlaybackCheckpointRepositoryTests: XCTestCase {
    private var temporaryDirectory: URL!

    override func setUpWithError() throws {
        temporaryDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent("LetterAudioBookCheckpointTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(
            at: temporaryDirectory,
            withIntermediateDirectories: true
        )
    }

    override func tearDownWithError() throws {
        if let temporaryDirectory {
            try? FileManager.default.removeItem(at: temporaryDirectory)
        }
        temporaryDirectory = nil
    }

    func test_saveCheckpoint_roundTripsFromMemory() throws {
        let repository = ImpPlaybackCheckpointRepository(inMemory: true)
        let bookID = uuid(1)
        let checkpoint = makeCheckpoint(chapterID: uuid(10), offset: 42, rate: 1.25)

        try repository.save(checkpoint, for: bookID)

        XCTAssertEqual(try repository.checkpoint(for: bookID), checkpoint)
        XCTAssertNil(try repository.checkpoint(for: uuid(2)))
    }

    func test_saveCheckpoint_persistsToStorageURLAndReloads() throws {
        let storageURL = makeStorageURL()
        let bookID = uuid(3)
        let checkpoint = makeCheckpoint(
            chapterID: uuid(30),
            offset: 120,
            rate: 2,
            furthestOffset: 180
        )

        let repository = ImpPlaybackCheckpointRepository(storageURL: storageURL)
        try repository.save(checkpoint, for: bookID)

        let reloaded = ImpPlaybackCheckpointRepository(storageURL: storageURL)
        XCTAssertEqual(try reloaded.checkpoint(for: bookID), checkpoint)
    }

    func test_saveCheckpoint_replacesExistingCheckpointForBook() throws {
        let storageURL = makeStorageURL()
        let bookID = uuid(4)
        let repository = ImpPlaybackCheckpointRepository(storageURL: storageURL)
        try repository.save(makeCheckpoint(chapterID: uuid(40), offset: 10, rate: 1), for: bookID)

        let replacement = makeCheckpoint(chapterID: uuid(41), offset: 90, rate: 1.5)
        try repository.save(replacement, for: bookID)

        let reloaded = ImpPlaybackCheckpointRepository(storageURL: storageURL)
        XCTAssertEqual(try reloaded.checkpoint(for: bookID), replacement)
    }

    func test_deleteCheckpoint_removesOnlyMatchingBookAndPersistsDeletion() throws {
        let storageURL = makeStorageURL()
        let deletedBookID = uuid(5)
        let keptBookID = uuid(6)
        let kept = makeCheckpoint(chapterID: uuid(60), offset: 70, rate: 1)
        let repository = ImpPlaybackCheckpointRepository(storageURL: storageURL)
        try repository.save(makeCheckpoint(chapterID: uuid(50), offset: 20, rate: 1), for: deletedBookID)
        try repository.save(kept, for: keptBookID)

        try repository.deleteCheckpoint(for: deletedBookID)

        let reloaded = ImpPlaybackCheckpointRepository(storageURL: storageURL)
        XCTAssertNil(try reloaded.checkpoint(for: deletedBookID))
        XCTAssertEqual(try reloaded.checkpoint(for: keptBookID), kept)
    }

    func test_load_ignoresCorruptStorageFile() throws {
        let storageURL = makeStorageURL()
        try Data("not-json".utf8).write(to: storageURL)

        let repository = ImpPlaybackCheckpointRepository(storageURL: storageURL)

        XCTAssertNil(try repository.checkpoint(for: uuid(7)))
    }

    private func makeCheckpoint(
        chapterID: UUID,
        offset: Int,
        rate: Double,
        furthestOffset: Int? = nil
    ) -> BookPlaybackCheckpoint {
        BookPlaybackCheckpoint(
            position: BookReadingPosition(chapterID: chapterID, characterOffset: offset),
            rateMultiplier: rate,
            furthestPosition: furthestOffset.map {
                BookReadingPosition(chapterID: chapterID, characterOffset: $0)
            }
        )
    }

    private func makeStorageURL() -> URL {
        temporaryDirectory.appendingPathComponent("checkpoints.json")
    }

    private func uuid(_ value: Int) -> UUID {
        UUID(uuidString: String(format: "00000000-0000-0000-0000-%012d", value))!
    }
}
