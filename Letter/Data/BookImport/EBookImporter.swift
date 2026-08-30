import Foundation

@MainActor
final class EBookImporter: BookImporting {
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
        return Book(title: parsed.title, format: format, chapters: parsed.chapters)
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
