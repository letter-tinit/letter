import Foundation

public struct BookBookmark: Identifiable, Codable, Equatable, Sendable {
    public let id: UUID
    public let bookID: UUID
    public let position: BookReadingPosition
    public let excerpt: String
    public let createdAt: Date

    public init(id: UUID, bookID: UUID, position: BookReadingPosition, excerpt: String, createdAt: Date) {
        self.id = id
        self.bookID = bookID
        self.position = position
        self.excerpt = excerpt
        self.createdAt = createdAt
    }
}

public struct BookPassage: Identifiable, Equatable, Sendable {
    public var id: Int { range.lowerBound }
    public let text: String
    public let range: Range<Int>
}

/// All ranges refer to UTF-16 units in the original chapter text.
public struct BookPassagePolicy {
    public init() {}

    public func passages(in content: String) -> [BookPassage] {
        let source = content as NSString
        let expression = try! NSRegularExpression(pattern: "[^\\r\\n]+")
        return expression.matches(in: content, range: NSRange(location: 0, length: source.length)).compactMap { match in
            let text = source.substring(with: match.range).trimmingCharacters(in: .whitespacesAndNewlines)
            guard !text.isEmpty else { return nil }
            return BookPassage(text: text, range: match.range.location..<(match.range.location + match.range.length))
        }
    }

    public func passage(at offset: Int, in passages: [BookPassage]) -> BookPassage? {
        passages.first { $0.range.contains(offset) }
            ?? passages.last { $0.range.lowerBound <= offset }
            ?? passages.first
    }

    /// A bookmark reserves its paragraph plus two paragraphs on either side.
    public func nearbyBookmark(at offset: Int, chapterID: UUID, passages: [BookPassage], bookmarks: [BookBookmark]) -> BookBookmark? {
        guard let current = passage(at: offset, in: passages),
              let index = passages.firstIndex(of: current) else { return nil }
        return bookmarks.filter { bookmark in
            guard bookmark.position.chapterID == chapterID,
                  let saved = passage(at: bookmark.position.characterOffset, in: passages),
                  let savedIndex = passages.firstIndex(of: saved) else { return false }
            return abs(index - savedIndex) <= 2
        }.sorted {
            let left = abs($0.position.characterOffset - current.range.lowerBound)
            let right = abs($1.position.characterOffset - current.range.lowerBound)
            return left == right ? $0.id.uuidString < $1.id.uuidString : left < right
        }.first
    }
}
