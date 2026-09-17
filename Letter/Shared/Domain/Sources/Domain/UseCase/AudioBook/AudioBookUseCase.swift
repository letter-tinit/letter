import Foundation
import Utility

public enum AudioBookError: Error, Equatable {
    case emptyBook
    case unsupportedFormat(BookFormat?)
    case malformedDocument
    case protectedDocument
    case chapterNotFound
}

@MainActor
public protocol AudioBookUseCase {
    func loadBooks() throws -> [Book]
    func importBook(from url: URL) async throws -> Book
    func deleteBook(id: UUID) throws
    func resetBook(id: UUID) throws
}

@MainActor
public final class ImpAudioBookUseCase: AudioBookUseCase {
    private let repository: any BookLibraryRepository
    private let importer: any BookImportRepository
    private let checkpointUseCase: any PlaybackCheckpointUseCase

    public init(
        repository: any BookLibraryRepository,
        importer: any BookImportRepository,
        checkpointUseCase: any PlaybackCheckpointUseCase
    ) {
        self.repository = repository
        self.importer = importer
        self.checkpointUseCase = checkpointUseCase
    }

    public func loadBooks() throws -> [Book] {
        try repository.fetchBooks().map(checkpointUseCase.restorePosition)
    }

    public func importBook(from url: URL) async throws -> Book {
        try Task.checkCancellation()
        let importer = self.importer
        let book = try await withCheckedThrowingContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                let result: Result<Book, Error> = autoreleasepool {
                    Result { try importer.importBook(from: url) }
                }
                continuation.resume(with: result)
            }
        }
        try Task.checkCancellation()
        guard !book.chapters.isEmpty, book.totalCharacterCount > 0 else {
            throw AudioBookError.emptyBook
        }
        try repository.save(book)
        return book
    }

    public func resetBook(id: UUID) throws {
        guard let original = try repository.fetchBooks().first(where: { $0.id == id }) else {
            throw AudioBookError.chapterNotFound
        }
        var reset = original
        reset.lastPosition = nil
        reset.furthestPosition = nil
        try repository.save(reset)
        do {
            try checkpointUseCase.deleteCheckpoint(for: id)
        } catch {
            try repository.save(original)
            throw error
        }
    }

    public func deleteBook(id: UUID) throws {
        try repository.deleteBook(id: id)
        try? checkpointUseCase.deleteCheckpoint(for: id)
    }
}
