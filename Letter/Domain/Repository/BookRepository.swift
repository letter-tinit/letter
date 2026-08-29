import Foundation

@MainActor
protocol BookRepository: AnyObject {
    func fetchBooks() throws -> [Book]
    func readBook(from url: URL) throws -> Book
    func save(_ book: Book) throws
    func delete(_ book: Book) throws
}
