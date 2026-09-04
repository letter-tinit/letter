import Foundation
import Observation
import Domain
import Utility
import Styleguide

public struct BookImportItem: Identifiable, Equatable {
    public enum State: Equatable {
        case indexing
        case failed(String)
    }

    public let id: UUID
    public let url: URL
    public let title: String
    public var state: State
}

@Observable
@MainActor
public final class AudioBookViewModel {
    private let useCase: any AudioBookUseCase

    private(set) var books: [Book] = []
    private(set) var importItems: [BookImportItem] = []
    public private(set) var toastMessage: ToastMessage?

    public init(useCase: any AudioBookUseCase) {
        self.useCase = useCase
        reloadBooks()
    }

    public func reloadBooks() {
        do {
            books = try useCase.loadBooks()
        } catch {
            toastMessage = ToastMessage(
                text: "audioBook.error.library".localized,
                type: .failure
            )
        }
    }

    public func importDocuments(from urls: [URL]) {
        for url in urls {
            let item = BookImportItem(
                id: UUID(),
                url: url,
                title: url.deletingPathExtension().lastPathComponent,
                state: .indexing
            )
            importItems.append(item)
            Task { await importItem(item.id) }
        }
    }

    public func retryImport(id: UUID) {
        guard importItems.contains(where: { $0.id == id }) else { return }
        updateImportState(id: id, state: .indexing)
        Task { await importItem(id) }
    }

    public func deleteBook(id: UUID) {
        do {
            try useCase.deleteBook(id: id)
            books.removeAll { $0.id == id }
            toastMessage = ToastMessage(
                text: "audioBook.delete.success".localized,
                type: .success
            )
        } catch {
            toastMessage = ToastMessage(
                text: "audioBook.error.delete".localized,
                type: .failure
            )
        }
    }

    private func importItem(_ id: UUID) async {
        guard let item = importItems.first(where: { $0.id == id }) else { return }
        let hasScopedAccess = item.url.startAccessingSecurityScopedResource()
        defer { if hasScopedAccess { item.url.stopAccessingSecurityScopedResource() } }

        do {
            let imported = try await useCase.importBook(from: item.url)
            books.removeAll { $0.id == imported.id }
            books.insert(imported, at: 0)
            importItems.removeAll { $0.id == id }
            toastMessage = ToastMessage(
                text: "audioBook.import.success".localized,
                type: .success
            )
        } catch let error as AudioBookError {
            failImport(id: id, message: error.localizedMessage)
        } catch {
            failImport(id: id, message: "audioBook.error.import".localized)
        }
    }

    private func failImport(id: UUID, message: String) {
        updateImportState(id: id, state: .failed(message))
        toastMessage = ToastMessage(text: message, type: .failure)
    }

    private func updateImportState(id: UUID, state: BookImportItem.State) {
        guard let index = importItems.firstIndex(where: { $0.id == id }) else { return }
        importItems[index].state = state
    }
}

extension AudioBookError {
    public var localizedMessage: String {
        switch self {
        case .protectedDocument: "audioBook.error.protected".localized
        case .unsupportedFormat: "audioBook.error.format".localized
        case .emptyBook: "audioBook.error.emptyBook".localized
        case .malformedDocument: "audioBook.error.malformed".localized
        case .chapterNotFound: "audioBook.error.library".localized
        }
    }
}
