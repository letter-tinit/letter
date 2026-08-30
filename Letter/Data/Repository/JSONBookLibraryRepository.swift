import Foundation

@MainActor
final class JSONBookLibraryRepository: BookLibraryRepository {
    private var books: [Book]
    private let storageURL: URL?

    init(inMemory: Bool = false) {
        if inMemory {
            storageURL = nil
            books = []
            return
        }

        let directory = try? FileManager.default.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )
        storageURL = directory?.appendingPathComponent("LetterBooks.json")
        if let storageURL,
           let data = try? Data(contentsOf: storageURL),
           let saved = try? JSONDecoder().decode([Book].self, from: data) {
            books = saved
        } else {
            books = []
        }
    }

    func fetchBooks() throws -> [Book] {
        books.sorted { $0.importedAt > $1.importedAt }
    }

    func save(_ book: Book) throws {
        var updated = books
        if let index = updated.firstIndex(where: { $0.id == book.id }) {
            updated[index] = book
        } else {
            updated.insert(book, at: 0)
        }
        try commit(updated)
    }

    func deleteBook(id: UUID) throws {
        try commit(books.filter { $0.id != id })
    }

    func updatePosition(bookID: UUID, position: BookReadingPosition) throws {
        guard let index = books.firstIndex(where: { $0.id == bookID }) else {
            throw AudioBookError.bookNotFound
        }
        var updated = books
        updated[index].updatePosition(
            chapterID: position.chapterID,
            characterOffset: position.characterOffset
        )
        try commit(updated)
    }

    private func commit(_ updatedBooks: [Book]) throws {
        if let storageURL {
            let data = try JSONEncoder().encode(updatedBooks)
            try data.write(to: storageURL, options: .atomic)
        }
        books = updatedBooks
    }
}
