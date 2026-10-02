import SwiftUI
import Domain
import Styleguide
import Utility

public struct BookmarkScreen: View {
    @State private var isConfirmingDeleteAll = false
    let book: Book
    @Environment(BookBookmarkViewModel.self) private var viewModel
    @Environment(AudioBookRouter.self) private var router

    private func openSelectedBookmark(_ bookmark: BookBookmark) {
        router.pop()
        if let playerIndex = router.path.lastIndex(where: { route in
            if case .player(let bookID, _) = route { return bookID == book.id }
            return false
        }) {
            router.path = Array(router.path.prefix(playerIndex + 1))
        } else {
            router.push(.player(bookID: book.id, chapterID: bookmark.position.chapterID))
        }
    }

    public var body: some View {
        List {
            ForEach(book.chapters) { chapter in
                let bookmarks = viewModel.bookmarks.filter { $0.position.chapterID == chapter.id }
                    .sorted { $0.position.characterOffset < $1.position.characterOffset }
                if !bookmarks.isEmpty {
                    Section {
                        ForEach(bookmarks) { bookmark in
                            Button {
                                viewModel.select(bookmark)
                                openSelectedBookmark(bookmark)
                            } label: {
                                Text(bookmark.excerpt)
                                    .customFont(.body)
                                    .foregroundStyle(.primary)
                                    .padding(8)
                                    .background(Color.yellow.opacity(0.2), in: RoundedRectangle(cornerRadius: 8))
                            }
                            .swipeActions(allowsFullSwipe: false) {
                                Button(role: .destructive) {
                                    viewModel.delete(bookmark)
                                } label: {
                                    Label("common.delete".localized, systemImage: "trash")
                                }
                            }
                        }
                    } header: { Text(chapter.displayTitle).customFont(.subheadline) }
                }
            }
        }
        .navigationTitle("audioBook.bookmark.title".localized)
        .overlay {
            if viewModel.isAvailable && viewModel.bookmarks.isEmpty {
                CommonEmptyView("audioBook.bookmark.empty".localized, systemImage: "bookmark")
            }
        }
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button(role: .destructive) {
                    isConfirmingDeleteAll = true
                } label: {
                    Image(systemName: "trash")
                }
                .accessibilityLabel("audioBook.bookmark.deleteAll".localized)
                .disabled(!viewModel.isAvailable || viewModel.loadedBookID != book.id || viewModel.bookmarks.isEmpty)
            }
        }
        .confirmationDialog("audioBook.bookmark.deleteAll.title".localized,
                            isPresented: $isConfirmingDeleteAll, titleVisibility: .visible) {
            Button("audioBook.bookmark.deleteAll".localized, role: .destructive) {
                viewModel.deleteAll(bookID: book.id)
            }
        } message: {
            Text("audioBook.bookmark.deleteAll.message".localized)
                .customFont(.body)
        }
        .task { viewModel.load(bookID: book.id) }
        .toast(message: viewModel.toastMessage)
    }
}
