import SwiftUI
import Domain
import Utility
import Styleguide

public struct AudioBookDetailScreen: View {
    @Environment(AudioBookRouter.self) private var router
    @State private var viewModel: AudioBookDetailViewModel
    @State private var expandedGroupIDs: Set<UUID> = []
    private let bookID: UUID

    public init(bookID: UUID, viewModel: AudioBookDetailViewModel) {
        self.bookID = bookID
        _viewModel = State(initialValue: viewModel)
    }

    public var body: some View {
        Group {
            if let book = viewModel.book {
            BaseScreen(.constant(book.title)) {
                List {
                    Section {
                        AudioBookDetailMetadata(book: book)
                    }

                    Section("audioBook.chapters".localized) {
                        AudioBookChapterGroups(
                            book: book,
                            expandedGroupIDs: $expandedGroupIDs
                        )
                    }
                }
                .scrollContentBackground(.hidden)
                .safeAreaInset(edge: .bottom) {
                    AudioBookMiniPlayer()
                }
            }
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    if let chapterID = resumeChapterID(for: book) {
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
        .toast(message: viewModel.toastMessage)
        .task { viewModel.load(bookID: bookID) }
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

    private func resumeChapterID(for book: Book) -> UUID? {
        book.lastPosition?.chapterID ?? book.furthestPosition?.chapterID
    }
}
