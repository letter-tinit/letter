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

    @Test
    func ignoresDenseTableOfContentsAndUsesStandaloneBodyHeadings() {
        let text = """
        Mục lục
        Chương 1 Phương pháp Khắc kỷ
        Chương 2 Bản chất của điều tốt
        Chương 3 Trị liệu cảm xúc
        Chương 4 Kỷ luật khát khao

        Chương 1
        Phương pháp Khắc kỷ
        Nội dung chương một được trình bày chi tiết ở đây.

        Chương 2
        Bản chất của điều tốt
        Nội dung chương hai được trình bày chi tiết ở đây.

        Chương 3
        Trị liệu cảm xúc
        Nội dung chương ba được trình bày chi tiết ở đây.

        Chương 4
        Kỷ luật khát khao
        Nội dung chương bốn được trình bày chi tiết ở đây.
        """

        let chapters = BookChapterSegmenter().chapters(from: text, fallbackTitle: "Book")

        #expect(chapters.count == 5)
        #expect(chapters[1].title == "Chương 1")
        #expect(chapters[1].content.contains("Nội dung chương một"))
        #expect(chapters[2].title == "Chương 2")
        #expect(chapters[4].content.contains("Nội dung chương bốn"))
    }
}
