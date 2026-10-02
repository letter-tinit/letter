import Foundation

@MainActor
public protocol BookBookmarkRepository: AnyObject {
    func fetch(bookID: UUID) throws -> [BookBookmark]
    func save(_ bookmark: BookBookmark) throws
    func delete(id: UUID) throws
    func deleteAll(bookID: UUID) throws
}
