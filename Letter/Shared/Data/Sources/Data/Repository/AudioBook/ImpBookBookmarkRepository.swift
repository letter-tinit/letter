import Foundation
import Domain

@MainActor
public final class ImpBookBookmarkRepository: BookBookmarkRepository {
    private let storageURL: URL?
    private var bookmarks: [BookBookmark]?

    public init(inMemory: Bool = false, storageURL: URL? = nil) {
        self.storageURL = inMemory ? nil : storageURL ?? FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first?.appendingPathComponent("LetterBookmarks.json")
    }

    private func load() throws -> [BookBookmark] {
        if let bookmarks { return bookmarks }
        guard let storageURL, FileManager.default.fileExists(atPath: storageURL.path) else { return [] }
        let loaded = try JSONDecoder().decode([BookBookmark].self, from: Data(contentsOf: storageURL))
        bookmarks = loaded
        return loaded
    }

    public func fetch(bookID: UUID) throws -> [BookBookmark] { try load().filter { $0.bookID == bookID } }
    public func save(_ bookmark: BookBookmark) throws {
        var updated = try load().filter { $0.id != bookmark.id }
        updated.append(bookmark)
        try commit(updated)
    }
    public func delete(id: UUID) throws { try commit(load().filter { $0.id != id }) }
    public func deleteAll(bookID: UUID) throws { try commit(load().filter { $0.bookID != bookID }) }

    private func commit(_ updated: [BookBookmark]) throws {
        if let storageURL {
            try FileManager.default.createDirectory(at: storageURL.deletingLastPathComponent(), withIntermediateDirectories: true)
            try JSONEncoder().encode(updated).write(to: storageURL, options: .atomic)
        }
        bookmarks = updated
    }
}
