import SwiftUI
import Domain
import Utility
import Styleguide

public struct AudioBookDetailScreen: View {
    @Environment(AudioBookRouter.self) private var router
    @Binding private var book: Book?
    @State private var expandedGroupIDs: Set<UUID> = []
    @State private var chapterSearchText = ""
    @State private var debouncedChapterSearchText = ""
    
    public init(book: Binding<Book?>) {
        _book = book
    }
    
    public var body: some View {
        Group {
            if let book {
                BaseScreen(.constant(book.title)) {
                    VStack {
                        AudioBookDetailMetadata(book: book)
                        
                        List {
                            AudioBookChapterGroups(
                                book: book,
                                expandedGroupIDs: $expandedGroupIDs,
                                searchText: debouncedChapterSearchText
                            )
                        }
                        .searchable(text: $chapterSearchText, prompt: "audioBook.searchChapters".localized)
                        .task(id: chapterSearchText) {
                            do {
                                try await Task.sleep(for: .milliseconds(250))
                                guard !Task.isCancelled else { return }
                                debouncedChapterSearchText = chapterSearchText
                            } catch {
                                // Cancellation is expected when the query changes while waiting.
                            }
                        }
                        .scrollContentBackground(.hidden)
                    }
                    .safeAreaInset(edge: .bottom) {
                        AudioBookMiniPlayer(bookID: book.id)
                    }
                }
                .toolbar {
                    ToolbarItem(placement: .topBarTrailing) {
                        if let chapterID = progressChapterID(for: book) {
                            Button {
                                router.push(.player(bookID: book.id, chapterID: chapterID))
                            } label: {
                                progressText(for: book)
                            }
                        } else {
                            progressText(for: book)
                        }
                    }
                }
            } else {
                CommonEmptyView("audioBook.error.library".localized, systemImage: "book.closed")
            }
        }
    }
    
    @ViewBuilder
    private func progressText(for book: Book) -> some View {
        Text(book.readingProgress == 0
             ? "0%"
             : String(format: "%.2f%%", book.readingProgress * 100)
        )
        .customFont(.subheadline, weight: .semibold)
        .foregroundStyle(.secondary)
    }
    
    private func progressChapterID(for book: Book) -> UUID? {
        (book.furthestPosition ?? book.lastPosition)?.chapterID
    }
}
