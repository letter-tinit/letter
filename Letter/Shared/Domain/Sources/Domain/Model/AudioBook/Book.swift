import Foundation
import Utility

public enum BookFormat: String, Codable, Sendable, CaseIterable {
    case text
    case rtf
    case pdf
    case epub
}

public enum BookSectionRole: String, Codable, Sendable {
    case copyright
    case publicationInfo
    case supplementary
}

public struct BookChapter: Identifiable, Codable, Sendable, Equatable, Hashable {
    public let id: UUID
    public let title: String
    public var content: String
    public let index: Int
    public let groupTitle: String?
    public let role: BookSectionRole?

    public init(
        id: UUID = UUID(),
        title: String,
        content: String,
        index: Int,
        groupTitle: String? = nil,
        role: BookSectionRole? = nil
    ) {
        self.id = id
        self.title = title
        self.content = content
        self.index = index
        self.groupTitle = groupTitle
        self.role = role
    }

    public var characterCount: Int { content.utf16.count }
}

public struct BookChapterGroup: Identifiable, Sendable, Equatable {
    public let id: UUID
    public let title: String?
    public let chapters: [BookChapter]
}

public struct BookReadingPosition: Codable, Sendable, Equatable {
    public let chapterID: UUID
    public let characterOffset: Int
}

public struct Book: Identifiable, Codable, Sendable, Equatable {
    public let id: UUID
    public var title: String
    public let format: BookFormat
    public let importedAt: Date
    public var chapters: [BookChapter]
    public var lastPosition: BookReadingPosition?
    public var furthestPosition: BookReadingPosition?
    public var coverData: Data?
    public var language: BookLanguage

    public init(
        id: UUID = UUID(),
        title: String,
        format: BookFormat,
        importedAt: Date = .now,
        chapters: [BookChapter],
        lastPosition: BookReadingPosition? = nil,
        furthestPosition: BookReadingPosition? = nil,
        coverData: Data? = nil,
        language: BookLanguage = .vietnamese
    ) {
        self.id = id
        self.title = title
        self.format = format
        self.importedAt = importedAt
        self.chapters = chapters.sorted { $0.index < $1.index }
        self.lastPosition = lastPosition
        self.furthestPosition = furthestPosition ?? lastPosition
        self.coverData = coverData
        self.language = language
    }

    public var totalCharacterCount: Int {
        chapters.reduce(0) { $0 + $1.characterCount }
    }

    public var chapterGroups: [BookChapterGroup] {
        var groups: [BookChapterGroup] = []
        for chapter in chapters {
            if let last = groups.last, last.title == chapter.groupTitle {
                groups[groups.count - 1] = BookChapterGroup(
                    id: last.id,
                    title: last.title,
                    chapters: last.chapters + [chapter]
                )
            } else {
                groups.append(
                    BookChapterGroup(
                        id: chapter.id,
                        title: chapter.groupTitle,
                        chapters: [chapter]
                    )
                )
            }
        }
        return groups
    }

    public var readingProgress: Double {
        guard let progressPosition = furthestPosition ?? lastPosition,
              let chapterIndex = chapters.firstIndex(where: { $0.id == progressPosition.chapterID }),
              totalCharacterCount > 0 else { return 0 }
        let completedCharacters = chapters[..<chapterIndex].reduce(0) { $0 + $1.characterCount }
        return min(Double(completedCharacters + progressPosition.characterOffset) / Double(totalCharacterCount), 1)
    }

    public mutating func updatePlaybackPosition(chapterID: UUID, characterOffset: Int) {
        guard let chapter = chapters.first(where: { $0.id == chapterID }) else { return }
        lastPosition = BookReadingPosition(
            chapterID: chapterID,
            characterOffset: min(max(characterOffset, 0), chapter.characterCount)
        )
    }

    public mutating func updateFurthestPosition(chapterID: UUID, characterOffset: Int) {
        guard let chapter = chapters.first(where: { $0.id == chapterID }) else { return }
        furthestPosition = BookReadingPosition(
            chapterID: chapterID,
            characterOffset: min(max(characterOffset, 0), chapter.characterCount)
        )
    }

    private enum CodingKeys: String, CodingKey {
        case id, title, format, importedAt, chapters, lastPosition, furthestPosition, coverData, language
        case content, readingProgress
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        title = try container.decode(String.self, forKey: .title)
        format = try container.decode(BookFormat.self, forKey: .format)
        importedAt = try container.decode(Date.self, forKey: .importedAt)

        if let decodedChapters = try container.decodeIfPresent([BookChapter].self, forKey: .chapters) {
            chapters = decodedChapters.sorted { $0.index < $1.index }
            lastPosition = try container.decodeIfPresent(BookReadingPosition.self, forKey: .lastPosition)
            furthestPosition = try container.decodeIfPresent(
                BookReadingPosition.self,
                forKey: .furthestPosition
            ) ?? lastPosition
            coverData = try container.decodeIfPresent(Data.self, forKey: .coverData)
            language = try container.decodeIfPresent(BookLanguage.self, forKey: .language) ?? .vietnamese
        } else {
            let legacyContent = try container.decodeIfPresent(String.self, forKey: .content) ?? ""
            let chapter = BookChapter(title: title, content: legacyContent, index: 0)
            chapters = [chapter]
            coverData = nil
            language = .vietnamese
            let legacyProgress = try container.decodeIfPresent(Double.self, forKey: .readingProgress) ?? 0
            lastPosition = BookReadingPosition(
                chapterID: chapter.id,
                characterOffset: Int(Double(chapter.characterCount) * min(max(legacyProgress, 0), 1))
            )
            furthestPosition = lastPosition
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(title, forKey: .title)
        try container.encode(format, forKey: .format)
        try container.encode(importedAt, forKey: .importedAt)
        try container.encode(chapters, forKey: .chapters)
        try container.encodeIfPresent(lastPosition, forKey: .lastPosition)
        try container.encodeIfPresent(furthestPosition, forKey: .furthestPosition)
        try container.encodeIfPresent(coverData, forKey: .coverData)
        try container.encode(language, forKey: .language)
    }
}
