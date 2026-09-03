import Foundation
import Domain
import Utility

public final class EBookImporter: BookImportRepository, @unchecked Sendable {
    private let parsers: [BookFormat: any BookDocumentParser]
    private let textNormalizer = ImportedBookTextNormalizer()

    public init() {
        let parsers = Self.defaultParsers
        self.parsers = Dictionary(uniqueKeysWithValues: parsers.map { ($0.format, $0) })
    }

    public init(parsers: [any BookDocumentParser]) {
        self.parsers = Dictionary(uniqueKeysWithValues: parsers.map { ($0.format, $0) })
    }

    public func importBook(from url: URL) throws -> Book {
        guard let format = BookFormat(fileExtension: url.pathExtension),
              let parser = parsers[format] else {
            throw AudioBookError.unsupportedFormat(nil)
        }
        let fallbackTitle = url.deletingPathExtension().lastPathComponent
        let parsed = try parser.parse(url: url, fallbackTitle: fallbackTitle)
        guard !parsed.chapters.isEmpty else { throw AudioBookError.emptyBook }
        let language = parsed.languageCode.flatMap(BookLanguage.init(languageCode:))
            ?? BookLanguageDetector().detect(chapters: parsed.chapters)
        let chapters = normalizedChapters(parsed.chapters)
        guard !chapters.isEmpty else { throw AudioBookError.emptyBook }
#if DEBUG
        let sourceCharacters = parsed.chapters.reduce(0) { $0 + $1.characterCount }
        let normalizedCharacters = chapters.reduce(0) { $0 + $1.characterCount }
        logDebug(
            "[Letter][BookImport] normalized format=\(format.rawValue) " +
            "characters=\(sourceCharacters)->\(normalizedCharacters) " +
            "chapters=\(parsed.chapters.count)->\(chapters.count)"
        )
#endif
        return Book(
            title: parsed.title,
            format: format,
            chapters: chapters,
            coverData: parsed.coverData,
            language: language
        )
    }

    private func normalizedChapters(_ chapters: [BookChapter]) -> [BookChapter] {
        let contents = textNormalizer.normalizeSections(chapters.map(\.content))
        var result: [BookChapter] = []
        for (chapter, content) in zip(chapters, contents) {
            guard !content.isEmpty else { continue }
            result.append(BookChapter(
                id: chapter.id,
                title: chapter.title,
                content: content,
                index: result.count,
                groupTitle: chapter.groupTitle,
                role: chapter.role
            ))
        }
        return result
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

extension BookFormat {
    public init?(fileExtension: String) {
        switch fileExtension.lowercased() {
        case "txt", "text", "md": self = .text
        case "rtf": self = .rtf
        case "pdf": self = .pdf
        case "epub": self = .epub
        default: return nil
        }
    }
}
