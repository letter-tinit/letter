import Foundation
import XCTest
@testable import Data
@testable import Domain

@MainActor
final class ImpBookLibraryRepositoryTests: XCTestCase {
    private var temporaryDirectory: URL!

    override func setUpWithError() throws {
        temporaryDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent("LetterBookLibraryTests-\(UUID().uuidString)", isDirectory: true)
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

    func test_save_insertsNewBooksAtTopAndPersistsOrder() throws {
        let storageURL = makeStorageURL()
        let older = makeBook(id: uuid(1), title: "Older", importedAt: date(100))
        let newer = makeBook(id: uuid(2), title: "Newer", importedAt: date(200))
        let repository = ImpBookLibraryRepository(storageURL: storageURL)

        try repository.save(older)
        try repository.save(newer)

        XCTAssertEqual(try repository.fetchBooks(), [newer, older])
        XCTAssertEqual(try ImpBookLibraryRepository(storageURL: storageURL).fetchBooks(), [newer, older])
    }

    func test_save_replacesExistingBookWithoutMovingIt() throws {
        let repository = ImpBookLibraryRepository(inMemory: true)
        let first = makeBook(id: uuid(3), title: "First", importedAt: date(100))
        let second = makeBook(id: uuid(4), title: "Second", importedAt: date(200))
        try repository.save(first)
        try repository.save(second)

        var updatedFirst = first
        updatedFirst.title = "First Updated"
        try repository.save(updatedFirst)

        XCTAssertEqual(try repository.fetchBooks(), [second, updatedFirst])
    }

    func test_saveBooksInOrder_persistsManualOrder() throws {
        let storageURL = makeStorageURL()
        let first = makeBook(id: uuid(5), title: "First", importedAt: date(100))
        let second = makeBook(id: uuid(6), title: "Second", importedAt: date(200))
        let third = makeBook(id: uuid(7), title: "Third", importedAt: date(300))
        let repository = ImpBookLibraryRepository(storageURL: storageURL)
        try repository.save(first)
        try repository.save(second)
        try repository.save(third)

        try repository.saveBooksInOrder([first, third, second])

        let reloaded = ImpBookLibraryRepository(storageURL: storageURL)
        XCTAssertEqual(try reloaded.fetchBooks(), [first, third, second])
    }

    func test_deleteBook_removesMatchingBookAndPersistsOrder() throws {
        let storageURL = makeStorageURL()
        let deleted = makeBook(id: uuid(8), title: "Deleted", importedAt: date(100))
        let kept = makeBook(id: uuid(9), title: "Kept", importedAt: date(200))
        let repository = ImpBookLibraryRepository(storageURL: storageURL)
        try repository.save(deleted)
        try repository.save(kept)

        try repository.deleteBook(id: deleted.id)

        XCTAssertEqual(try ImpBookLibraryRepository(storageURL: storageURL).fetchBooks(), [kept])
    }

    private func makeBook(id: UUID, title: String, importedAt: Date) -> Book {
        Book(
            id: id,
            title: title,
            format: .epub,
            importedAt: importedAt,
            chapters: [
                BookChapter(
                    id: uuid(100),
                    title: "Chapter",
                    content: "Content",
                    index: 0
                )
            ]
        )
    }

    private func makeStorageURL() -> URL {
        temporaryDirectory.appendingPathComponent("books.json")
    }

    private func uuid(_ value: Int) -> UUID {
        UUID(uuidString: String(format: "00000000-0000-0000-0000-%012d", value))!
    }

    private func date(_ value: TimeInterval) -> Date {
        Date(timeIntervalSince1970: value)
    }
}
