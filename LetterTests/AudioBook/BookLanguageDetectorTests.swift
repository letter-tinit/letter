import Testing
@testable import Letter

struct BookLanguageDetectorTests {
    @Test
    func detectsEnglishFromBookContent() {
        let chapter = BookChapter(
            title: "Chapter One",
            content: "The people in this book are learning how to work with each other and make the best decisions.",
            index: 0
        )

        #expect(BookLanguageDetector().detect(chapters: [chapter]) == .english)
    }

    @Test
    func detectsVietnameseFromBookContent() {
        let chapter = BookChapter(
            title: "Chương Một",
            content: "Những người trong cuốn sách này đang học cách làm việc với nhau và đưa ra quyết định tốt nhất.",
            index: 0
        )

        #expect(BookLanguageDetector().detect(chapters: [chapter]) == .vietnamese)
    }
}
