import Foundation
import Testing
@testable import Letter

@MainActor
struct BookLibraryUseCaseTests {
    @Test
    func importPersistsParsedBook() throws {
        let chapter = BookChapter(title: "One", content: "Content", index: 0)
        let imported = Book(title: "Imported", format: .epub, chapters: [chapter])
        let repository = FakeBookLibraryRepository()
        let checkpointUseCase = makeCheckpointUseCase()
        let useCase = DefaultBookLibraryUseCase(
            repository: repository,
            importer: FakeBookImporter(result: .success(imported)),
            checkpointUseCase: checkpointUseCase
        )

        let output = try useCase.importBook(from: URL(fileURLWithPath: "/tmp/book.epub"))

        #expect(output == imported)
        #expect(repository.books == [imported])
    }

    @Test
    func rejectsBookWithoutReadableChapters() {
        let empty = Book(title: "Empty", format: .text, chapters: [])
        let useCase = DefaultBookLibraryUseCase(
            repository: FakeBookLibraryRepository(),
            importer: FakeBookImporter(result: .success(empty)),
            checkpointUseCase: makeCheckpointUseCase()
        )

        #expect(throws: AudioBookError.emptyBook) {
            try useCase.importBook(from: URL(fileURLWithPath: "/tmp/empty.txt"))
        }
    }

    private func makeCheckpointUseCase() -> DefaultPlaybackCheckpointUseCase {
        DefaultPlaybackCheckpointUseCase(repository: FakePlaybackCheckpointRepository())
    }
}

@MainActor
private final class FakeBookLibraryRepository: BookLibraryRepository {
    var books: [Book] = []

    func fetchBooks() throws -> [Book] { books }

    func save(_ book: Book) throws {
        books.append(book)
    }

    func deleteBook(id: UUID) throws {
        books.removeAll { $0.id == id }
    }

}

@MainActor
private final class FakePlaybackCheckpointRepository: PlaybackCheckpointRepository {
    func checkpoint(for bookID: UUID) throws -> BookPlaybackCheckpoint? { nil }
    func save(_ checkpoint: BookPlaybackCheckpoint, for bookID: UUID) throws {}
    func deleteCheckpoint(for bookID: UUID) throws {}
}

@MainActor
private final class FakeBookImporter: BookImporting, @unchecked Sendable {
    let result: Result<Book, Error>

    init(result: Result<Book, Error>) {
        self.result = result
    }

    func importBook(from url: URL) throws -> Book {
        try result.get()
    }
}
