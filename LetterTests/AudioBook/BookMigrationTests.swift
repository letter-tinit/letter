import Foundation
import Testing
@testable import Letter

struct BookMigrationTests {
    @Test
    func groupsConsecutiveChaptersWhileKeepingFlatChaptersVisible() {
        let chapters = [
            BookChapter(title: "Lời nói đầu", content: "A", index: 0),
            BookChapter(title: "Mục 1", content: "B", index: 1, groupTitle: "Phần I"),
            BookChapter(title: "Mục 2", content: "C", index: 2, groupTitle: "Phần I"),
            BookChapter(title: "Phụ lục", content: "D", index: 3)
        ]
        let book = Book(title: "Book", format: .epub, chapters: chapters)

        #expect(book.chapterGroups.count == 3)
        #expect(book.chapterGroups[0].title == nil)
        #expect(book.chapterGroups[1].title == "Phần I")
        #expect(book.chapterGroups[1].chapters.map(\.title) == ["Mục 1", "Mục 2"])
    }

    @Test
    func decodesLegacySingleContentBookAsChapter() throws {
        let id = UUID()
        let json = """
        {
          "id": "\(id.uuidString)",
          "title": "Legacy",
          "content": "0123456789",
          "format": "text",
          "importedAt": 0,
          "readingProgress": 0.5
        }
        """

        let book = try JSONDecoder().decode(Book.self, from: Data(json.utf8))

        #expect(book.chapters.count == 1)
        #expect(book.chapters[0].content == "0123456789")
        #expect(book.lastPosition?.characterOffset == 5)
        #expect(book.readingProgress == 0.5)
        #expect(book.language == .vietnamese)
    }

    @Test
    func clampsReadingPositionToChapterBounds() {
        let chapter = BookChapter(title: "One", content: "12345", index: 0)
        var book = Book(title: "Book", format: .text, chapters: [chapter])

        book.updatePosition(chapterID: chapter.id, characterOffset: 99)

        #expect(book.lastPosition?.characterOffset == 5)
        #expect(book.readingProgress == 1)
    }
}
