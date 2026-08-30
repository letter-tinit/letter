import Foundation
import Testing
@testable import Letter

struct BookMigrationTests {
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
