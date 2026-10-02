import Foundation
import Observation
import Domain
import Styleguide
import Utility

@Observable @MainActor
public final class BookBookmarkViewModel {
    private let useCase: any BookBookmarkUseCase
    public private(set) var bookmarkCounts: [UUID: Int] = [:]
    public private(set) var bookmarks: [BookBookmark] = []
    public private(set) var toastMessage: ToastMessage?
    public private(set) var selectedBookmark: BookBookmark?
    public private(set) var loadedBookID: UUID?
    public private(set) var isAvailable = false

    public init(useCase: any BookBookmarkUseCase) { self.useCase = useCase }

    public func load(bookID: UUID) {
        do {
            let loaded = try useCase.load(bookID: bookID)
            bookmarkCounts[bookID] = loaded.count
            bookmarks = loaded
            loadedBookID = bookID
            isAvailable = true
        } catch {
            isAvailable = false
            toastMessage = ToastMessage(text: "audioBook.bookmark.error".localized, type: .failure)
        }
    }

    public func toggle(book: Book, position: BookReadingPosition) {
        do {
            let change = try useCase.toggle(book: book, position: position, now: Date())
            load(bookID: book.id)
            let key = change == .added ? "audioBook.bookmark.added" : "audioBook.bookmark.removed"
            toastMessage = ToastMessage(text: key.localized, type: .success)
        } catch {
            toastMessage = ToastMessage(text: "audioBook.bookmark.error".localized, type: .failure)
        }
    }

    public func delete(_ bookmark: BookBookmark) {
        do {
            let remaining = try useCase.delete(id: bookmark.id, bookID: bookmark.bookID)
            applyDeletion(bookID: bookmark.bookID, remaining: remaining, messageKey: "audioBook.bookmark.removed")
        } catch {
            toastMessage = ToastMessage(text: "audioBook.bookmark.error".localized, type: .failure)
        }
    }

    public func deleteAll(bookID: UUID) {
        do {
            try useCase.deleteAll(bookID: bookID)
            applyDeletion(bookID: bookID, remaining: [], messageKey: "audioBook.bookmark.allRemoved")
        } catch {
            toastMessage = ToastMessage(text: "audioBook.bookmark.error".localized, type: .failure)
        }
    }

    private func applyDeletion(bookID: UUID, remaining: [BookBookmark], messageKey: String) {
        bookmarkCounts[bookID] = remaining.count
        if loadedBookID == bookID { bookmarks = remaining }
        if let selectedBookmark, selectedBookmark.bookID == bookID,
           !remaining.contains(where: { $0.id == selectedBookmark.id }) { clearSelection() }
        toastMessage = ToastMessage(text: messageKey.localized, type: .success)
    }

    public func isBookmarked(bookID: UUID, chapter: BookChapter, offset: Int) -> Bool {
        guard loadedBookID == bookID else { return false }
        let policy = BookPassagePolicy()
        return policy.nearbyBookmark(at: offset, chapterID: chapter.id,
            passages: policy.passages(in: chapter.content), bookmarks: bookmarks) != nil
    }

    public func loadCounts(bookIDs: [UUID]) {
        var counts: [UUID: Int] = [:]
        for id in bookIDs {
            do { counts[id] = try useCase.load(bookID: id).count }
            catch { toastMessage = ToastMessage(text: "audioBook.bookmark.error".localized, type: .failure) }
        }
        bookmarkCounts = counts
    }

    public func refreshAfterReset(bookID: UUID) {
        bookmarkCounts[bookID] = 0
        if selectedBookmark?.bookID == bookID { clearSelection() }
        if loadedBookID == bookID { load(bookID: bookID) }
    }

    public func select(_ bookmark: BookBookmark) { selectedBookmark = bookmark }
    public func clearSelection() { selectedBookmark = nil }
}
