import Testing
@testable import Letter

struct BookChapterSegmenterTests {
    @Test
    func splitsVietnameseAndEnglishHeadingsInOrder() {
        let text = """
        Lời mở đầu
        Chương 1: Khởi đầu
        Nội dung thứ nhất.
        Chapter 2 - The Journey
        Nội dung thứ hai.
        """

        let chapters = BookChapterSegmenter().chapters(from: text, fallbackTitle: "Book")

        #expect(chapters.count == 3)
        #expect(chapters[0].title == "Book")
        #expect(chapters[0].content == "Lời mở đầu")
        #expect(chapters[1].title == "Chương 1: Khởi đầu")
        #expect(chapters[1].content.contains("Nội dung thứ nhất"))
        #expect(chapters[2].title == "Chapter 2 - The Journey")
        #expect(chapters[2].index == 2)
    }

    @Test
    func createsOneChapterWhenNoHeadingExists() {
        let chapters = BookChapterSegmenter().chapters(
            from: "  Một văn bản liền mạch.  ",
            fallbackTitle: "Tên sách"
        )

        #expect(chapters.count == 1)
        #expect(chapters[0].title == "Tên sách")
        #expect(chapters[0].content == "Một văn bản liền mạch.")
    }
}
