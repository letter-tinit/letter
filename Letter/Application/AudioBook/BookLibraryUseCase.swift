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
    func importBook(from url: URL) async throws -> Book
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
        try importBookSync(from: url)
    }

    func importBook(from url: URL) async throws -> Book {
        let importer = self.importer
        let book = try await withCheckedThrowingContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                // XML/PDF parsing creates many temporary Foundation objects. Keep
                // their autoreleased lifetime scoped to this import so importing
                // several books cannot retain every intermediate object until the
                // main run loop gets a chance to drain its pool.
                let result: Result<Book, Error> = autoreleasepool {
                    Result { try importer.importBook(from: url) }
                }
                continuation.resume(with: result)
            }
        }
        guard !book.chapters.isEmpty, book.totalCharacterCount > 0 else {
            throw AudioBookError.emptyBook
        }
        try repository.save(book)
        return book
    }

    private func importBookSync(from url: URL) throws -> Book {
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
