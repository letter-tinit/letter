import Foundation
@testable import Domain

@MainActor
final class FakeBookLibraryRepository: BookLibraryRepository {
    var books: [Book]
    var savedBooks: [Book] = []
    var savedBookOrders: [[Book]] = []
    var deletedBookIDs: [UUID] = []

    init(books: [Book] = []) {
        self.books = books
    }

    func fetchBooks() throws -> [Book] {
        books
    }

    func save(_ book: Book) throws {
        savedBooks.append(book)
        books.removeAll { $0.id == book.id }
        books.append(book)
    }

    func saveBooksInOrder(_ books: [Book]) throws {
        savedBookOrders.append(books)
        self.books = books
    }

    func deleteBook(id: UUID) throws {
        deletedBookIDs.append(id)
        books.removeAll { $0.id == id }
    }
}
