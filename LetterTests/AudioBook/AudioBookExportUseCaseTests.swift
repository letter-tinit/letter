import Foundation
import Testing
@testable import Letter

@MainActor
struct AudioBookExportUseCaseTests {
    @Test
    func rejectsBookWithoutReadableContent() async {
        let useCase = DefaultAudioBookExportUseCase(exporter: FakeBookAudioExporter())
        let book = Book(title: "Empty", format: .epub, chapters: [])

        await #expect(throws: AudioBookExportError.emptyBook) {
            try await useCase.export(
                book: book,
                chapterIDs: [],
                rate: 1,
                onProgress: { _ in }
            )
        }
    }

    @Test
    func clampsReadingRateBeforeCallingExporter() async throws {
        let exporter = FakeBookAudioExporter()
        let useCase = DefaultAudioBookExportUseCase(exporter: exporter)
        let book = Book(
            title: "Book",
            format: .epub,
            chapters: [BookChapter(title: "One", content: "Content", index: 0)]
        )

        _ = try await useCase.export(
            book: book,
            chapterIDs: Set(book.chapters.map(\.id)),
            rate: 8,
            onProgress: { _ in }
        )

        #expect(exporter.receivedRate == 3)
    }

    @Test
    func exportsSelectedChaptersInBookOrder() async throws {
        let first = BookChapter(title: "One", content: "First", index: 0)
        let second = BookChapter(title: "Two", content: "Second", index: 1)
        let third = BookChapter(title: "Three", content: "Third", index: 2)
        let book = Book(title: "Book", format: .epub, chapters: [first, second, third])
        let exporter = FakeBookAudioExporter()
        let useCase = DefaultAudioBookExportUseCase(exporter: exporter)

        _ = try await useCase.export(
            book: book,
            chapterIDs: [third.id, first.id],
            rate: 1,
            onProgress: { _ in }
        )

        #expect(exporter.receivedBook?.chapters.map(\.id) == [first.id, third.id])
    }

    @Test
    func rejectsEmptyChapterSelection() async {
        let chapter = BookChapter(title: "One", content: "Content", index: 0)
        let book = Book(title: "Book", format: .epub, chapters: [chapter])
        let useCase = DefaultAudioBookExportUseCase(exporter: FakeBookAudioExporter())

        await #expect(throws: AudioBookExportError.emptyBook) {
            try await useCase.export(
                book: book,
                chapterIDs: [],
                rate: 1,
                onProgress: { _ in }
            )
        }
    }
}

@MainActor
private final class FakeBookAudioExporter: BookAudioExporting {
    private(set) var receivedRate: Double?
    private(set) var receivedBook: Book?

    func export(
        book: Book,
        rate: Double,
        onProgress: @escaping (Double) -> Void
    ) async throws -> URL {
        receivedBook = book
        receivedRate = rate
        onProgress(1)
        return URL(fileURLWithPath: "/tmp/book.m4a")
    }

    func cancel() {}
    func discardExport(at url: URL) {}
}
