import Foundation
import PDFKit
import UIKit

struct PlainTextBookParser: BookDocumentParser {
    let format = BookFormat.text
    private let segmenter = BookChapterSegmenter()

    func parse(url: URL, fallbackTitle: String) throws -> ParsedBookDocument {
        let data = try Data(contentsOf: url)
        guard let text = data.decodedBookText else { throw AudioBookError.malformedDocument }
        return ParsedBookDocument(
            title: fallbackTitle,
            chapters: segmenter.chapters(from: text, fallbackTitle: fallbackTitle)
        )
    }
}

struct RTFBookParser: BookDocumentParser {
    let format = BookFormat.rtf
    private let segmenter = BookChapterSegmenter()

    func parse(url: URL, fallbackTitle: String) throws -> ParsedBookDocument {
        let data = try Data(contentsOf: url)
        let text = try NSAttributedString(
            data: data,
            options: [.documentType: NSAttributedString.DocumentType.rtf],
            documentAttributes: nil
        ).string
        return ParsedBookDocument(
            title: fallbackTitle,
            chapters: segmenter.chapters(from: text, fallbackTitle: fallbackTitle)
        )
    }
}

struct PDFBookParser: BookDocumentParser {
    let format = BookFormat.pdf
    private let segmenter = BookChapterSegmenter()

    func parse(url: URL, fallbackTitle: String) throws -> ParsedBookDocument {
        guard let document = PDFDocument(url: url) else { throw AudioBookError.malformedDocument }
        let pages = (0..<document.pageCount).compactMap { document.page(at: $0)?.string }
        let detected = segmenter.chapters(from: pages.joined(separator: "\n\n"), fallbackTitle: fallbackTitle)
        let chapters: [BookChapter]
        if detected.count == 1, pages.count > 1 {
            chapters = pages.enumerated().compactMap { index, page in
                let content = page.trimmingCharacters(in: .whitespacesAndNewlines)
                return content.isEmpty ? nil : BookChapter(title: "Page \(index + 1)", content: content, index: index)
            }
        } else {
            chapters = detected
        }
        let coverData = document.page(at: 0)?.thumbnail(
            of: CGSize(width: 320, height: 480),
            for: .mediaBox
        ).jpegData(compressionQuality: 0.8)
        return ParsedBookDocument(title: fallbackTitle, chapters: chapters, coverData: coverData)
    }
}

extension Data {
    var decodedBookText: String? {
        let encodings: [String.Encoding] = [.utf8, .utf16, .unicode, .windowsCP1252, .isoLatin1]
        return encodings.lazy.compactMap { String(data: self, encoding: $0) }.first
    }
}
