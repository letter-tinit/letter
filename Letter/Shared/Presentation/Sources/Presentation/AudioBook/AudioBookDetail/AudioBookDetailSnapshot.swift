import Foundation
import Domain

struct AudioBookDetailSnapshot {
    struct Chapter: Identifiable {
        let id: UUID
        let title: String
        let characterCount: Int
    }

    struct Group: Identifiable {
        let id: UUID
        let title: String?
        let chapters: [Chapter]
    }

    let groups: [Group]
    private let precedingCharacters: [UUID: Int]
    private let totalCharacters: Int

    init(book: Book) {
        var preceding: [UUID: Int] = [:]
        var total = 0
        groups = book.chapterGroups.map { group in
            Group(id: group.id, title: group.title, chapters: group.chapters.map { chapter in
                let count = chapter.characterCount
                preceding[chapter.id] = total
                total += count
                return Chapter(id: chapter.id, title: chapter.displayTitle, characterCount: count)
            })
        }
        precedingCharacters = preceding
        totalCharacters = total
    }

    func readingProgress(at position: BookReadingPosition?) -> Double {
        guard let position, let preceding = precedingCharacters[position.chapterID],
              totalCharacters > 0 else { return 0 }
        return min(Double(preceding + position.characterOffset) / Double(totalCharacters), 1)
    }
}
