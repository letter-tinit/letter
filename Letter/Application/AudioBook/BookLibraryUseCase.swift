import Foundation

enum AudioBookError: Error, Equatable {
    case emptyBook
    case unsupportedFormat(BookFormat?)
    case malformedDocument
    case protectedDocument
    case bookNotFound
    case chapterNotFound
}

@MainActor
protocol BookLibraryUseCase {
    func loadBooks() throws -> [Book]
    func importBook(from url: URL) throws -> Book
    func deleteBook(id: UUID) throws
    func savePosition(bookID: UUID, chapterID: UUID, characterOffset: Int) throws
}

@MainActor
final class DefaultBookLibraryUseCase: BookLibraryUseCase {
    private let repository: any BookLibraryRepository
    private let importer: any BookImporting

    init(repository: any BookLibraryRepository, importer: any BookImporting) {
        self.repository = repository
        self.importer = importer
    }

    func loadBooks() throws -> [Book] {
        try repository.fetchBooks()
    }

    func importBook(from url: URL) throws -> Book {
        let book = try importer.importBook(from: url)
        guard !book.chapters.isEmpty, book.totalCharacterCount > 0 else {
            throw AudioBookError.emptyBook
        }
        try repository.save(book)
        return book
    }

    func deleteBook(id: UUID) throws {
        try repository.deleteBook(id: id)
    }

    func savePosition(bookID: UUID, chapterID: UUID, characterOffset: Int) throws {
        try repository.updatePosition(
            bookID: bookID,
            position: BookReadingPosition(chapterID: chapterID, characterOffset: characterOffset)
        )
    }
}
