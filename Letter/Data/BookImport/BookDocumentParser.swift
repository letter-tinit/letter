import Foundation

struct ParsedBookDocument {
    let title: String
    let chapters: [BookChapter]
    let coverData: Data?
    let languageCode: String?

    init(
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

protocol BookDocumentParser {
    var format: BookFormat { get }
    func parse(url: URL, fallbackTitle: String) throws -> ParsedBookDocument
}
