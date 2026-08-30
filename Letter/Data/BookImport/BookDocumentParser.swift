import Foundation

struct ParsedBookDocument {
    let title: String
    let chapters: [BookChapter]
    let coverData: Data?

    init(title: String, chapters: [BookChapter], coverData: Data? = nil) {
        self.title = title
        self.chapters = chapters
        self.coverData = coverData
    }
}

protocol BookDocumentParser {
    var format: BookFormat { get }
    func parse(url: URL, fallbackTitle: String) throws -> ParsedBookDocument
}
