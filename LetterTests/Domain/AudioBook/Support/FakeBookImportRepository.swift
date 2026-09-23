import Foundation
@testable import Domain

final class FakeBookImportRepository: BookImportRepository, @unchecked Sendable {
    var result: Result<Book, Error>
    var importedURLs: [URL] = []

    init(result: Result<Book, Error>) {
        self.result = result
    }

    func importBook(from url: URL) throws -> Book {
        importedURLs.append(url)
        return try result.get()
    }
}
