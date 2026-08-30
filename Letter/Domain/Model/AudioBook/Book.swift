import Foundation

enum BookFormat: String, Codable, Sendable, CaseIterable {
    case text
    case rtf
    case pdf
    case epub
}

struct BookChapter: Identifiable, Codable, Sendable, Equatable, Hashable {
    let id: UUID
    let title: String
    var content: String
    let index: Int

    init(id: UUID = UUID(), title: String, content: String, index: Int) {
        self.id = id
        self.title = title
        self.content = content
        self.index = index
    }

    var characterCount: Int { content.utf16.count }
}

struct BookReadingPosition: Codable, Sendable, Equatable {
    let chapterID: UUID
    let characterOffset: Int
}

struct Book: Identifiable, Codable, Sendable, Equatable {
    let id: UUID
    var title: String
    let format: BookFormat
    let importedAt: Date
    var chapters: [BookChapter]
    var lastPosition: BookReadingPosition?

    init(
        id: UUID = UUID(),
        title: String,
        format: BookFormat,
        importedAt: Date = .now,
        chapters: [BookChapter],
        lastPosition: BookReadingPosition? = nil
    ) {
        self.id = id
        self.title = title
        self.format = format
        self.importedAt = importedAt
        self.chapters = chapters.sorted { $0.index < $1.index }
        self.lastPosition = lastPosition
    }

    var totalCharacterCount: Int {
        chapters.reduce(0) { $0 + $1.characterCount }
    }

    var readingProgress: Double {
        guard let lastPosition,
              let chapterIndex = chapters.firstIndex(where: { $0.id == lastPosition.chapterID }),
              totalCharacterCount > 0 else { return 0 }
        let completedCharacters = chapters[..<chapterIndex].reduce(0) { $0 + $1.characterCount }
        return min(Double(completedCharacters + lastPosition.characterOffset) / Double(totalCharacterCount), 1)
    }

    mutating func updatePosition(chapterID: UUID, characterOffset: Int) {
        guard let chapter = chapters.first(where: { $0.id == chapterID }) else { return }
        lastPosition = BookReadingPosition(
            chapterID: chapterID,
            characterOffset: min(max(characterOffset, 0), chapter.characterCount)
        )
    }

    private enum CodingKeys: String, CodingKey {
        case id, title, format, importedAt, chapters, lastPosition
        case content, readingProgress
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        title = try container.decode(String.self, forKey: .title)
        format = try container.decode(BookFormat.self, forKey: .format)
        importedAt = try container.decode(Date.self, forKey: .importedAt)

        if let decodedChapters = try container.decodeIfPresent([BookChapter].self, forKey: .chapters) {
            chapters = decodedChapters.sorted { $0.index < $1.index }
            lastPosition = try container.decodeIfPresent(BookReadingPosition.self, forKey: .lastPosition)
        } else {
            let legacyContent = try container.decodeIfPresent(String.self, forKey: .content) ?? ""
            let chapter = BookChapter(title: title, content: legacyContent, index: 0)
            chapters = [chapter]
            let legacyProgress = try container.decodeIfPresent(Double.self, forKey: .readingProgress) ?? 0
            lastPosition = BookReadingPosition(
                chapterID: chapter.id,
                characterOffset: Int(Double(chapter.characterCount) * min(max(legacyProgress, 0), 1))
            )
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(title, forKey: .title)
        try container.encode(format, forKey: .format)
        try container.encode(importedAt, forKey: .importedAt)
        try container.encode(chapters, forKey: .chapters)
        try container.encodeIfPresent(lastPosition, forKey: .lastPosition)
    }
}
