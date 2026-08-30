import Foundation

final class EBookImporter: BookImportRepository, @unchecked Sendable {
    private let parsers: [BookFormat: any BookDocumentParser]

    init() {
        let parsers = Self.defaultParsers
        self.parsers = Dictionary(uniqueKeysWithValues: parsers.map { ($0.format, $0) })
    }

    init(parsers: [any BookDocumentParser]) {
        self.parsers = Dictionary(uniqueKeysWithValues: parsers.map { ($0.format, $0) })
    }

    func importBook(from url: URL) throws -> Book {
        guard let format = BookFormat(fileExtension: url.pathExtension),
              let parser = parsers[format] else {
            throw AudioBookError.unsupportedFormat(nil)
        }
        let fallbackTitle = url.deletingPathExtension().lastPathComponent
        let parsed = try parser.parse(url: url, fallbackTitle: fallbackTitle)
        guard !parsed.chapters.isEmpty else { throw AudioBookError.emptyBook }
        let language = parsed.languageCode.flatMap(BookLanguage.init(languageCode:))
            ?? BookLanguageDetector().detect(chapters: parsed.chapters)
        return Book(
            title: parsed.title,
            format: format,
            chapters: parsed.chapters,
            coverData: parsed.coverData,
            language: language
        )
    }

    private static var defaultParsers: [any BookDocumentParser] {
        [
            PlainTextBookParser(),
            RTFBookParser(),
            PDFBookParser(),
            EPUBBookParser()
        ]
    }
}

private extension BookFormat {
    init?(fileExtension: String) {
        switch fileExtension.lowercased() {
        case "txt", "text", "md": self = .text
        case "rtf": self = .rtf
        case "pdf": self = .pdf
        case "epub": self = .epub
        default: return nil
        }
    }
}
