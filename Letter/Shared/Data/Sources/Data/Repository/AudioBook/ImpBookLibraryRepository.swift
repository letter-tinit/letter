import Foundation
import Domain
import Utility

@MainActor
public final class ImpBookLibraryRepository: BookLibraryRepository {
    private var books: [Book]
    private let storageURL: URL?

    public init(inMemory: Bool = false, storageURL: URL? = nil) {
        if inMemory {
            self.storageURL = nil
            books = []
            return
        }

        self.storageURL = storageURL ?? Self.defaultStorageURL()
        if let storageURL = self.storageURL,
           let data = try? Data(contentsOf: storageURL),
           let saved = try? JSONDecoder().decode([Book].self, from: data) {
            books = saved
        } else {
            books = []
        }
    }

    public func fetchBooks() throws -> [Book] {
        books
    }

    public func save(_ book: Book) throws {
        var updated = books
        if let index = updated.firstIndex(where: { $0.id == book.id }) {
            updated[index] = book
        } else {
            updated.insert(book, at: 0)
        }
        try commit(updated)
    }

    public func saveBooksInOrder(_ books: [Book]) throws {
        try commit(books)
    }

    public func deleteBook(id: UUID) throws {
        try commit(books.filter { $0.id != id })
    }

    private func commit(_ updatedBooks: [Book]) throws {
        if let storageURL {
            let data = try JSONEncoder().encode(updatedBooks)
            try data.write(to: storageURL, options: .atomic)
        }
        books = updatedBooks
    }

    private static func defaultStorageURL() -> URL? {
        let directory = try? FileManager.default.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )
        return directory?.appendingPathComponent("LetterBooks.json")
    }
}
