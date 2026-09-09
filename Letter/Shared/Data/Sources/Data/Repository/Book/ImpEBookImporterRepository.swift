import Foundation
import Domain
import LetterEbook

public final class ImpEBookImporterRepository: BookImportRepository, @unchecked Sendable {
    private let importer: EbookImporter

    public init(importer: EbookImporter = EbookImporter()) {
        self.importer = importer
    }

    public func importBook(from url: URL) throws -> Book {
        let document: EbookDocument
        do {
            document = try importer.importDocument(from: url)
        } catch let error as EbookError {
            throw map(error)
        }

        guard let format = BookFormat(rawValue: document.format.rawValue) else {
            throw AudioBookError.unsupportedFormat(nil)
        }
        let chapters = document.chapters.map {
            BookChapter(
                title: $0.title,
                content: $0.content,
                index: $0.index,
                groupTitle: $0.groupTitle,
                role: $0.role.map(map)
            )
        }
        guard !chapters.isEmpty else { throw AudioBookError.emptyBook }
        let language = document.languageCode.flatMap(BookLanguage.init(languageCode:))
            ?? .vietnamese
        return Book(
            title: document.title,
            format: format,
            chapters: chapters,
            coverData: document.coverData,
            language: language
        )
    }

    private func map(_ error: EbookError) -> AudioBookError {
        switch error {
        case .emptyDocument:
            .emptyBook
        case .unsupportedFormat:
            .unsupportedFormat(nil)
        case .malformedDocument:
            .malformedDocument
        case .protectedDocument:
            .protectedDocument
        }
    }

    private func map(_ role: EbookSectionRole) -> BookSectionRole {
        switch role {
        case .copyright:
            .copyright
        case .publicationInfo:
            .publicationInfo
        case .supplementary:
            .supplementary
        }
    }
}
