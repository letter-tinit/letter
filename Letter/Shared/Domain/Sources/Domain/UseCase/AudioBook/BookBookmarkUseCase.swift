import Foundation

public enum BookBookmarkChange { case added, removed }
public enum BookBookmarkError: Error { case chapterNotFound, emptyChapter, bookmarkNotFound }

@MainActor
public protocol BookBookmarkUseCase {
    func load(bookID: UUID) throws -> [BookBookmark]
    func delete(id: UUID, bookID: UUID) throws -> [BookBookmark]
    func deleteAll(bookID: UUID) throws
    func toggle(book: Book, position: BookReadingPosition, now: Date) throws -> BookBookmarkChange
}

@MainActor
public final class ImpBookBookmarkUseCase: BookBookmarkUseCase {
    private let repository: any BookBookmarkRepository
    private let policy = BookPassagePolicy()

    public init(repository: any BookBookmarkRepository) { self.repository = repository }

    public func load(bookID: UUID) throws -> [BookBookmark] { try repository.fetch(bookID: bookID) }

    public func delete(id: UUID, bookID: UUID) throws -> [BookBookmark] {
        let bookmarks = try repository.fetch(bookID: bookID)
        guard bookmarks.contains(where: { $0.id == id }) else { throw BookBookmarkError.bookmarkNotFound }
        try repository.delete(id: id)
        return bookmarks.filter { $0.id != id }
    }

    public func deleteAll(bookID: UUID) throws {
        try repository.deleteAll(bookID: bookID)
    }

    public func toggle(book: Book, position: BookReadingPosition, now: Date) throws -> BookBookmarkChange {
        guard let chapter = book.chapters.first(where: { $0.id == position.chapterID }) else {
            throw BookBookmarkError.chapterNotFound
        }
        let passages = policy.passages(in: chapter.content)
        guard let passage = policy.passage(at: position.characterOffset, in: passages) else {
            throw BookBookmarkError.emptyChapter
        }
        let bookmarks = try repository.fetch(bookID: book.id)
        if let existing = policy.nearbyBookmark(at: position.characterOffset, chapterID: chapter.id, passages: passages, bookmarks: bookmarks) {
            try repository.delete(id: existing.id)
            return .removed
        }
        try repository.save(BookBookmark(id: UUID(), bookID: book.id,
            position: BookReadingPosition(chapterID: chapter.id, characterOffset: passage.range.lowerBound),
            excerpt: passage.text, createdAt: now))
        return .added
    }
}
