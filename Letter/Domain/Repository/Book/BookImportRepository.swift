import Foundation

protocol BookImportRepository: AnyObject, Sendable {
    func importBook(from url: URL) throws -> Book
}
