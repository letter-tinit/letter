import Foundation
import Domain
import Utility

public struct ParsedBookDocument {
    public let title: String
    public let chapters: [BookChapter]
    public let coverData: Data?
    public let languageCode: String?

    public init(
        title: String,
        chapters: [BookChapter],
        coverData: Data? = nil,
        languageCode: String? = nil
    ) {
        self.title = title
        self.chapters = chapters
        self.coverData = coverData
        self.languageCode = languageCode
    }
}

public protocol BookDocumentParser {
    var format: BookFormat { get }
    func parse(url: URL, fallbackTitle: String) throws -> ParsedBookDocument
}
