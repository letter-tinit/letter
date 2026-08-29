import Foundation
import PDFKit
import UIKit

@MainActor
final class ImpBookRepository: BookRepository {
    private var books: [Book] = []
    private let storageURL: URL?

    init(inMemory: Bool = false) {
        if inMemory {
            storageURL = nil
        } else {
            let directory = try? FileManager.default.url(
                for: .applicationSupportDirectory,
                in: .userDomainMask,
                appropriateFor: nil,
                create: true
            )
            storageURL = directory?.appendingPathComponent("LetterBooks.json")
            if let storageURL,
               let data = try? Data(contentsOf: storageURL),
               let saved = try? JSONDecoder().decode([Book].self, from: data) {
                books = saved
            }
        }
    }

    func fetchBooks() throws -> [Book] { books }

    func readBook(from url: URL) throws -> Book {
        let format: BookFormat
        let content: String
        switch url.pathExtension.lowercased() {
        case "pdf":
            format = .pdf
            guard let document = PDFDocument(url: url) else {
                throw AudioBookError.unsupportedDocument
            }
            content = (0..<document.pageCount)
                .compactMap { document.page(at: $0)?.string }
                .joined(separator: "\n\n")
        case "rtf":
            format = .rtf
            let data = try Data(contentsOf: url)
            content = try NSAttributedString(
                data: data,
                options: [.documentType: NSAttributedString.DocumentType.rtf],
                documentAttributes: nil
            ).string
        default:
            format = .text
            guard let value = String(data: try Data(contentsOf: url), encoding: .utf8) else {
                throw AudioBookError.unsupportedDocument
            }
            content = value
        }
        return Book(title: url.deletingPathExtension().lastPathComponent, content: content, format: format)
    }

    func save(_ book: Book) throws {
        if let index = books.firstIndex(where: { $0.id == book.id }) {
            books[index] = book
        } else {
            books.insert(book, at: 0)
        }
        try persist()
    }

    func delete(_ book: Book) throws {
        books.removeAll { $0.id == book.id }
        try persist()
    }

    private func persist() throws {
        guard let storageURL else { return }
        let data = try JSONEncoder().encode(books)
        try data.write(to: storageURL, options: .atomic)
    }
}
