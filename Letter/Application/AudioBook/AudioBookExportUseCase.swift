import Foundation

enum AudioBookExportError: Error, Equatable {
    case emptyBook
    case synthesisFailed
    case encodingFailed
}

@MainActor
protocol BookAudioExporting: AnyObject {
    func export(
        book: Book,
        rate: Double,
        onProgress: @escaping (Double) -> Void
    ) async throws -> URL
    func cancel()
    func discardExport(at url: URL)
}

@MainActor
protocol AudioBookExportUseCase: AnyObject {
    func export(
        book: Book,
        chapterIDs: Set<UUID>,
        rate: Double,
        onProgress: @escaping (Double) -> Void
    ) async throws -> URL
    func cancel()
    func discardExport(at url: URL)
}

@MainActor
final class DefaultAudioBookExportUseCase: AudioBookExportUseCase {
    private let exporter: any BookAudioExporting

    init(exporter: any BookAudioExporting) {
        self.exporter = exporter
    }

    func export(
        book: Book,
        chapterIDs: Set<UUID>,
        rate: Double,
        onProgress: @escaping (Double) -> Void
    ) async throws -> URL {
        let selectedChapters = book.chapters.filter { chapterIDs.contains($0.id) }
        guard !selectedChapters.isEmpty,
              selectedChapters.contains(where: { $0.characterCount > 0 }) else {
            throw AudioBookExportError.emptyBook
        }
        var selectedBook = book
        selectedBook.chapters = selectedChapters
        if selectedChapters.count == 1, let chapter = selectedChapters.first {
            let chapterTitle = chapter.title.isEmpty ? "\(chapter.index + 1)" : chapter.title
            selectedBook.title = "\(book.title) - \(chapterTitle)"
        }
        return try await exporter.export(
            book: selectedBook,
            rate: min(max(rate, 0.5), 3),
            onProgress: onProgress
        )
    }

    func cancel() {
        exporter.cancel()
    }

    func discardExport(at url: URL) {
        exporter.discardExport(at: url)
    }
}
