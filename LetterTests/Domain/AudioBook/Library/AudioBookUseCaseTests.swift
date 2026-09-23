import XCTest
@testable import Domain

@MainActor
final class AudioBookUseCaseTests: XCTestCase {
    func test_loadBooks_restoresCheckpointPositions() throws {
        let chapter = AudioBookTestFactory.chapter(content: String(repeating: "a", count: 100), index: 0)
        let book = AudioBookTestFactory.book(chapters: [chapter])
        let checkpoint = BookPlaybackCheckpoint(
            position: BookReadingPosition(chapterID: chapter.id, characterOffset: 30),
            rateMultiplier: 1
        )
        let useCase = ImpAudioBookUseCase(
            repository: FakeBookLibraryRepository(books: [book]),
            importer: FakeBookImportRepository(result: .success(book)),
            checkpointUseCase: ImpPlaybackCheckpointUseCase(
                repository: FakePlaybackCheckpointRepository(checkpoints: [book.id: checkpoint])
            )
        )

        let books = try useCase.loadBooks()

        XCTAssertEqual(books.first?.id, book.id)
        XCTAssertLessThan(books.first?.lastPosition?.characterOffset ?? 999, 30)
    }

    func test_importBook_savesImportedBook() async throws {
        let book = AudioBookTestFactory.book()
        let repository = FakeBookLibraryRepository()
        let importer = FakeBookImportRepository(result: .success(book))
        let useCase = ImpAudioBookUseCase(
            repository: repository,
            importer: importer,
            checkpointUseCase: ImpPlaybackCheckpointUseCase(repository: FakePlaybackCheckpointRepository())
        )
        let url = URL(fileURLWithPath: "/tmp/book.epub")

        let imported = try await useCase.importBook(from: url)

        XCTAssertEqual(imported, book)
        XCTAssertEqual(repository.savedBooks, [book])
        XCTAssertEqual(importer.importedURLs, [url])
    }

    func test_importBook_rejectsEmptyBook() async {
        let emptyBook = AudioBookTestFactory.book(chapters: [])
        let useCase = ImpAudioBookUseCase(
            repository: FakeBookLibraryRepository(),
            importer: FakeBookImportRepository(result: .success(emptyBook)),
            checkpointUseCase: ImpPlaybackCheckpointUseCase(repository: FakePlaybackCheckpointRepository())
        )

        do {
            _ = try await useCase.importBook(from: URL(fileURLWithPath: "/tmp/empty.txt"))
            XCTFail("Expected emptyBook")
        } catch {
            XCTAssertEqual(error as? AudioBookError, .emptyBook)
        }
    }

    func test_resetBook_clearsPositionsAndDeletesCheckpoint() throws {
        let chapter = AudioBookTestFactory.chapter()
        let book = AudioBookTestFactory.book(
            chapters: [chapter],
            lastPosition: BookReadingPosition(chapterID: chapter.id, characterOffset: 3)
        )
        let repository = FakeBookLibraryRepository(books: [book])
        let checkpointRepository = FakePlaybackCheckpointRepository()
        let useCase = ImpAudioBookUseCase(
            repository: repository,
            importer: FakeBookImportRepository(result: .success(book)),
            checkpointUseCase: ImpPlaybackCheckpointUseCase(repository: checkpointRepository)
        )

        try useCase.resetBook(id: book.id)

        XCTAssertEqual(repository.savedBooks.last?.id, book.id)
        XCTAssertNil(repository.savedBooks.last?.lastPosition)
        XCTAssertNil(repository.savedBooks.last?.furthestPosition)
        XCTAssertEqual(checkpointRepository.deletedBookIDs, [book.id])
    }

    func test_deleteBook_deletesBookAndCheckpoint() throws {
        let book = AudioBookTestFactory.book()
        let repository = FakeBookLibraryRepository(books: [book])
        let checkpointRepository = FakePlaybackCheckpointRepository()
        let useCase = ImpAudioBookUseCase(
            repository: repository,
            importer: FakeBookImportRepository(result: .success(book)),
            checkpointUseCase: ImpPlaybackCheckpointUseCase(repository: checkpointRepository)
        )

        try useCase.deleteBook(id: book.id)

        XCTAssertEqual(repository.deletedBookIDs, [book.id])
        XCTAssertEqual(checkpointRepository.deletedBookIDs, [book.id])
    }
}
