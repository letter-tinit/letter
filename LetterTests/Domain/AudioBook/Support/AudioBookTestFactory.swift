import Foundation
@testable import Domain

enum AudioBookTestFactory {
    static let importedAt = Date(timeIntervalSince1970: 1_700_000_000)

    static func chapter(
        id: UUID = UUID(),
        title: String = "Chapter",
        content: String = "This is a readable chapter. It has enough text for playback.",
        index: Int = 0,
        groupTitle: String? = nil,
        role: BookSectionRole? = nil
    ) -> BookChapter {
        BookChapter(
            id: id,
            title: title,
            content: content,
            index: index,
            groupTitle: groupTitle,
            role: role
        )
    }

    static func book(
        id: UUID = UUID(),
        title: String = "Sample Book",
        format: BookFormat = .epub,
        chapters: [BookChapter]? = nil,
        lastPosition: BookReadingPosition? = nil,
        furthestPosition: BookReadingPosition? = nil,
        language: BookLanguage = .vietnamese
    ) -> Book {
        Book(
            id: id,
            title: title,
            format: format,
            importedAt: importedAt,
            chapters: chapters ?? [chapter()],
            lastPosition: lastPosition,
            furthestPosition: furthestPosition,
            language: language
        )
    }
}
