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
        let useCase = DefaultBookLibraryUseCase(
            repository: repository,
            importer: FakeBookImporter(result: .success(imported))
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
            importer: FakeBookImporter(result: .success(empty))
        )

        #expect(throws: AudioBookError.emptyBook) {
            try useCase.importBook(from: URL(fileURLWithPath: "/tmp/empty.txt"))
        }
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

    func updatePosition(bookID: UUID, position: BookReadingPosition) throws {
        guard let index = books.firstIndex(where: { $0.id == bookID }) else {
            throw AudioBookError.bookNotFound
        }
        books[index].updatePosition(
            chapterID: position.chapterID,
            characterOffset: position.characterOffset
        )
    }
}

@MainActor
private final class FakeBookImporter: BookImporting {
    let result: Result<Book, Error>

    init(result: Result<Book, Error>) {
        self.result = result
    }

    func importBook(from url: URL) throws -> Book {
        try result.get()
    }
}
