import Foundation

enum AudioBookError: Error, Equatable {
    case emptyBook
    case unsupportedFormat(BookFormat?)
    case malformedDocument
    case protectedDocument
    case chapterNotFound
}

@MainActor
protocol BookLibraryUseCase {
    func loadBooks() throws -> [Book]
    func importBook(from url: URL) async throws -> Book
    func deleteBook(id: UUID) throws
}

@MainActor
final class ImpBookLibraryUseCase: BookLibraryUseCase {
    private let repository: any BookLibraryRepository
    private let importer: any BookImportRepository
    private let checkpointUseCase: any PlaybackCheckpointUseCase

    init(
        repository: any BookLibraryRepository,
        importer: any BookImportRepository,
        checkpointUseCase: any PlaybackCheckpointUseCase
    ) {
        self.repository = repository
        self.importer = importer
        self.checkpointUseCase = checkpointUseCase
    }

    func loadBooks() throws -> [Book] {
        try repository.fetchBooks().map(checkpointUseCase.restorePosition)
    }

    func importBook(from url: URL) async throws -> Book {
        let importer = self.importer
        let book = try await withCheckedThrowingContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
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

    func deleteBook(id: UUID) throws {
        try repository.deleteBook(id: id)
        try? checkpointUseCase.deleteCheckpoint(for: id)
    }
}
