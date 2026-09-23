import XCTest
@testable import Domain

final class BookModelTests: XCTestCase {
    func test_init_sortsChaptersByIndex() {
        let second = AudioBookTestFactory.chapter(title: "Second", index: 1)
        let first = AudioBookTestFactory.chapter(title: "First", index: 0)

        let book = AudioBookTestFactory.book(chapters: [second, first])

        XCTAssertEqual(book.chapters.map(\.title), ["First", "Second"])
    }

    func test_chapterGroups_groupsAdjacentChaptersByGroupTitle() {
        let chapters = [
            AudioBookTestFactory.chapter(title: "One", index: 0, groupTitle: "Part 1"),
            AudioBookTestFactory.chapter(title: "Two", index: 1, groupTitle: "Part 1"),
            AudioBookTestFactory.chapter(title: "Three", index: 2, groupTitle: "Part 2")
        ]

        let groups = AudioBookTestFactory.book(chapters: chapters).chapterGroups

        XCTAssertEqual(groups.map(\.title), ["Part 1", "Part 2"])
        XCTAssertEqual(groups[0].chapters.map(\.title), ["One", "Two"])
        XCTAssertEqual(groups[1].chapters.map(\.title), ["Three"])
    }

    func test_readingProgress_usesFurthestPositionAcrossChapters() {
        let first = AudioBookTestFactory.chapter(content: String(repeating: "a", count: 10), index: 0)
        let second = AudioBookTestFactory.chapter(content: String(repeating: "b", count: 10), index: 1)
        let book = AudioBookTestFactory.book(
            chapters: [first, second],
            furthestPosition: BookReadingPosition(chapterID: second.id, characterOffset: 5)
        )

        XCTAssertEqual(book.readingProgress, 0.75)
    }

    func test_updatePositions_clampOffsetsToChapterBounds() {
        let chapter = AudioBookTestFactory.chapter(content: "Hello", index: 0)
        var book = AudioBookTestFactory.book(chapters: [chapter])

        book.updatePlaybackPosition(chapterID: chapter.id, characterOffset: 99)
        book.updateFurthestPosition(chapterID: chapter.id, characterOffset: -2)

        XCTAssertEqual(book.lastPosition?.characterOffset, 5)
        XCTAssertEqual(book.furthestPosition?.characterOffset, 0)
    }
}
