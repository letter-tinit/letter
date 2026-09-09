import Foundation
import PDFKit
import UIKit
import Domain
import Utility

public struct PlainTextBookParser: BookDocumentParser {
    public let format = BookFormat.text
    private let segmenter = BookChapterSegmenter()
    private let textNormalizer = ImportedBookTextNormalizer()

    public func parse(url: URL, fallbackTitle: String) throws -> ParsedBookDocument {
        let data = try Data(contentsOf: url)
        guard let source = data.decodedBookText else { throw AudioBookError.malformedDocument }
        let text = textNormalizer.normalizeDocument(source)
        return ParsedBookDocument(
            title: fallbackTitle,
            chapters: segmenter.chapters(from: text, fallbackTitle: fallbackTitle)
        )
    }
}

public struct RTFBookParser: BookDocumentParser {
    public let format = BookFormat.rtf
    private let segmenter = BookChapterSegmenter()
    private let textNormalizer = ImportedBookTextNormalizer()

    public func parse(url: URL, fallbackTitle: String) throws -> ParsedBookDocument {
        let data = try Data(contentsOf: url)
        let source = try NSAttributedString(
            data: data,
            options: [.documentType: NSAttributedString.DocumentType.rtf],
            documentAttributes: nil
        ).string
        let text = textNormalizer.normalizeDocument(source)
        return ParsedBookDocument(
            title: fallbackTitle,
            chapters: segmenter.chapters(from: text, fallbackTitle: fallbackTitle)
        )
    }
}

public struct PDFBookParser: BookDocumentParser {
    public let format = BookFormat.pdf
    private let segmenter = BookChapterSegmenter()
    private let textNormalizer = ImportedBookTextNormalizer()

    public func parse(url: URL, fallbackTitle: String) throws -> ParsedBookDocument {
        guard let document = PDFDocument(url: url) else { throw AudioBookError.malformedDocument }
        let pageTexts = (0..<document.pageCount).map { document.page(at: $0)?.string }
        let pages = textNormalizer.normalizePDFPages(pageTexts.compactMap { $0 })
        let detected = segmenter.chapters(
            from: pages.joined(separator: "\n\n"),
            fallbackTitle: fallbackTitle
        )
        let chapters: [BookChapter]
        let strategy: String
        if detected.count == 1, pages.count > 1 {
            strategy = "page-fallback"
            chapters = pages.enumerated().compactMap { index, page in
                let content = page.trimmingCharacters(in: .whitespacesAndNewlines)
                return content.isEmpty ? nil : BookChapter(title: "Page \(index + 1)", content: content, index: index)
            }
        } else {
            strategy = "heading-segmentation"
            chapters = detected
        }
        logSummary(
            bookTitle: fallbackTitle,
            document: document,
            pageTexts: pageTexts,
            chapters: chapters,
            strategy: strategy
        )
        let coverData = document.page(at: 0)?.thumbnail(
            of: CGSize(width: 320, height: 480),
            for: .mediaBox
        ).jpegData(compressionQuality: 0.8)
        return ParsedBookDocument(title: fallbackTitle, chapters: chapters, coverData: coverData)
    }

    private func logSummary(
        bookTitle: String,
        document: PDFDocument,
        pageTexts: [String?],
        chapters: [BookChapter],
        strategy: String
    ) {
        let readablePages = pageTexts.compactMap { $0 }.filter {
            !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        }
        let totalCharacters = readablePages.reduce(0) { $0 + $1.utf16.count }
        logDebug(
            "[Letter][PDF] book=\(bookTitle) | pages=\(document.pageCount) | readablePages=\(readablePages.count) | emptyPages=\(document.pageCount - readablePages.count) | characters=\(totalCharacters) | chapters=\(chapters.count) | strategy=\(strategy) | locked=\(document.isLocked)"
        )
        for (index, text) in pageTexts.enumerated() where text?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty != false {
            logDebug("[Letter][PDF] empty page=\(index + 1)")
        }
        for chapter in chapters {
            logDebug(
                "[Letter][PDF] chapter=\(chapter.index + 1) | title=\(chapter.title) | characters=\(chapter.characterCount)"
            )
        }
    }
}

extension Data {
    public var decodedBookText: String? {
        let encodings: [String.Encoding] = [.utf8, .utf16, .unicode, .windowsCP1252, .isoLatin1]
        return encodings.lazy.compactMap { String(data: self, encoding: $0) }.first
    }
}
