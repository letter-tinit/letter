import SwiftUI
import Domain
import Utility
import Styleguide

public struct AudioBookPlayerScreen: View {
    private let router: AudioBookRouter
    @Environment(AudioBookPlayerViewModel.self) private var viewModel
    @Environment(BookBookmarkViewModel.self) private var bookmarks
    @Binding private var book: Book?
    public let chapterID: UUID
    @State private var displayedChapterID: UUID
    @State private var isPlayerPresented = false
    @State private var hasPresentedPlayer = false
    @State private var scrollOffset: Int?
    @State private var playerDetent = AudioBookPlayerSheetDetent.collapsed
    
    public init(book: Binding<Book?>, chapterID: UUID, router: AudioBookRouter) {
        self.router = router
        _book = book
        self.chapterID = chapterID
        _displayedChapterID = State(initialValue: chapterID)
    }
    
    public var body: some View {
        Group {
            if let book,
               let chapter = book.chapters.first(where: { $0.id == displayedChapterID }) {
                BaseScreen(.constant(chapter.displayTitle)) {
                    AppScrollView {
                        AudioBookChapterTextView(
                            content: chapter.content,
                            activeOffset: viewModel.isActive(bookID: book.id, chapterID: chapter.id)
                                ? viewModel.currentCharacterOffset : nil,
                            bookmarks: bookmarks.loadedBookID == book.id ? bookmarks.bookmarks.filter { $0.position.chapterID == chapter.id } : [],
                            scrollOffset: scrollOffset
                        )
                        .id(chapter.id)
                    }
                }
                .onAppear {
                    viewModel.openChapterForViewing(bookID: book.id, chapterID: displayedChapterID)
                    consumeSelectedBookmark(for: book)
                    bookmarks.load(bookID: book.id)
                    if isReaderVisible { presentPlayerIfNeeded() }
                }
                .onChange(of: viewModel.activeChapterID) { _, activeChapterID in
                    guard viewModel.activeBookID == book.id,
                          let activeChapterID else { return }
                    displayedChapterID = activeChapterID
                    if scrollOffset != viewModel.currentCharacterOffset { scrollOffset = nil }
                }
                .onChange(of: router.path) { _, _ in
                    if isReaderVisible {
                        consumeSelectedBookmark(for: book)
                        presentPlayerIfNeeded()
                    } else {
                        dismissPlayerForNavigation()
                    }
                }
                .sheet(isPresented: $isPlayerPresented) {
                    AudioBookPlayerPopup(book: book, chapter: chapter)
                        .presentationDetents(
                            [AudioBookPlayerSheetDetent.collapsed, .medium],
                            selection: $playerDetent
                        )
                        .presentationDragIndicator(.visible)
                        .presentationCornerRadius(28)
                        .presentationBackground(.regularMaterial)
                        .presentationBackgroundInteraction(.enabled(upThrough: .medium))
                        .interactiveDismissDisabled()
                }
                .toolbar {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button {
                            router.push(.bookmarks(bookID: book.id))
                        } label: {
                            Image(systemName: "bookmark")
                        }
                        .accessibilityLabel("audioBook.bookmark.title".localized)
                    }
                }
            } else {
                CommonEmptyView("audioBook.error.library".localized, systemImage: "waveform")
            }
        }
        .toast(message: viewModel.toastMessage)
        .toast(message: bookmarks.toastMessage)
    }

    private var isReaderVisible: Bool {
        guard let book else { return false }
        return router.path.last == .player(bookID: book.id, chapterID: chapterID)
    }

    private func consumeSelectedBookmark(for book: Book) {
        guard let bookmark = bookmarks.selectedBookmark, bookmark.bookID == book.id else { return }
        viewModel.openPosition(bookID: book.id, position: bookmark.position)
        displayedChapterID = bookmark.position.chapterID
        scrollOffset = bookmark.position.characterOffset
        bookmarks.clearSelection()
    }

    private func presentPlayerIfNeeded() {
        guard !hasPresentedPlayer else {
            isPlayerPresented = true
            return
        }
        hasPresentedPlayer = true
        playerDetent = .medium
        isPlayerPresented = true
    }

    private func dismissPlayerForNavigation() {
        var transaction = Transaction()
        transaction.animation = .easeOut(duration: 0.12)
        withTransaction(transaction) {
            isPlayerPresented = false
        }
    }
}

private enum AudioBookPlayerSheetDetent {
    static let collapsed = PresentationDetent.height(92)
}

private struct AudioBookPlayerPopup: View {
    let book: Book
    let chapter: BookChapter
    @Environment(AudioBookPlayerViewModel.self) private var player
    @Environment(BookBookmarkViewModel.self) private var bookmarks

    private var position: BookReadingPosition? {
        guard player.isActive(bookID: book.id, chapterID: chapter.id) else { return nil }
        return BookReadingPosition(chapterID: chapter.id, characterOffset: player.currentCharacterOffset)
    }

    private var isBookmarked: Bool {
        guard let position, bookmarks.loadedBookID == book.id else { return false }
        return bookmarks.isBookmarked(bookID: book.id, chapter: chapter, offset: position.characterOffset)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                AudioBookPlayerControls(book: book, chapter: chapter, showsTitle: false)
                    .padding(.horizontal, 20)
                    .padding(.top, 10)
                    .padding(.bottom, 26)
            }
            .toolbarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text(book.title)
                        .customFont(.headline)
                        .lineLimit(1)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        guard let position else { return }
                        bookmarks.toggle(book: book, position: position)
                    } label: {
                        Image(systemName: isBookmarked ? "bookmark.fill" : "bookmark")
                            .customFont(.title3)
                    }
                    .disabled(position == nil || !bookmarks.isAvailable)
                    .accessibilityLabel((isBookmarked ? "audioBook.bookmark.remove" : "audioBook.bookmark.add").localized)
                    .accessibilityValue((isBookmarked ? "audioBook.bookmark.saved" : "audioBook.bookmark.unsaved").localized)
                }
            }
        }
    }
}
