import Foundation

@MainActor
protocol BookUseCase {
    func loadBooks() throws -> [Book]
    func importBook(from url: URL) throws -> Book
    func update(_ book: Book) throws
    func delete(_ book: Book) throws
}

@MainActor
final class ImpBookUseCase: BookUseCase {
    private let repository: any BookRepository

    init(repository: any BookRepository) {
        self.repository = repository
    }

    func loadBooks() throws -> [Book] {
        try repository.fetchBooks()
    }

    func importBook(from url: URL) throws -> Book {
        let book = try repository.readBook(from: url)
        guard !book.content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw AudioBookError.emptyText
        }
        try repository.save(book)
        return book
    }

    func update(_ book: Book) throws { try repository.save(book) }
    func delete(_ book: Book) throws { try repository.delete(book) }
}
