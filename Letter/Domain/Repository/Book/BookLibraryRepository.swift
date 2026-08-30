import Foundation

@MainActor
protocol BookLibraryRepository: AnyObject {
    func fetchBooks() throws -> [Book]
    func save(_ book: Book) throws
    func deleteBook(id: UUID) throws
}
