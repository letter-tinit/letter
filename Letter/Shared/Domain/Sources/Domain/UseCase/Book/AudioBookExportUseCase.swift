import Foundation
import Utility

public enum AudioBookExportError: Error, Equatable {
    case emptyBook
    case synthesisFailed
    case encodingFailed
}

@MainActor
public protocol AudioBookExportUseCase: AnyObject {
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
public final class ImpAudioBookExportUseCase: AudioBookExportUseCase {
    private let exporter: any BookAudioExportRepository

    public init(exporter: any BookAudioExportRepository) {
        self.exporter = exporter
    }

    public func export(
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

    public func cancel() {
        exporter.cancel()
    }

    public func discardExport(at url: URL) {
        exporter.discardExport(at: url)
    }
}
