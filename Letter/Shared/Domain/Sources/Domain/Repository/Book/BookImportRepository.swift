import Foundation
import Utility

public protocol BookImportRepository: AnyObject, Sendable {
    func importBook(from url: URL) throws -> Book
}
