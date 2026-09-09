import SwiftUI
import Domain
import Utility
import Styleguide

public struct AudioBookDetailScreen: View {
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
            } else {
                ContentUnavailableView("audioBook.error.library".localized, systemImage: "book.closed")
            }
        }
        .toast(message: viewModel.toastMessage)
        .task { viewModel.load(bookID: bookID) }
    }
}
