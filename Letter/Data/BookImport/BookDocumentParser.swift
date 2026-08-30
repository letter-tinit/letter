import Foundation

struct ParsedBookDocument {
    let title: String
    let chapters: [BookChapter]
}

protocol BookDocumentParser {
    var format: BookFormat { get }
    func parse(url: URL, fallbackTitle: String) throws -> ParsedBookDocument
}
