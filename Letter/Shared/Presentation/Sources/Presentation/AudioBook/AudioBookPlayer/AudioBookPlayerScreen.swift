import SwiftUI
import Domain
import Utility
import Styleguide

public struct AudioBookPlayerScreen: View {
    @Environment(AudioBookPlayerViewModel.self) private var viewModel
    @Binding private var book: Book?
    public let chapterID: UUID
    @State private var displayedChapterID: UUID
    
    public init(book: Binding<Book?>, chapterID: UUID) {
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
                        Text(chapter.content)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .textSelection(.enabled)
                            .padding()
                    }
                    .safeAreaInset(edge: .bottom) {
                        AudioBookPlayerControls(book: book, chapter: chapter)
                            .padding()
                            .background(.ultraThinMaterial)
                    }
                }
                .onAppear {
                    viewModel.openChapterForViewing(bookID: book.id, chapterID: chapterID)
                }
                .onChange(of: viewModel.activeChapterID) { _, activeChapterID in
                    guard viewModel.activeBookID == book.id,
                          let activeChapterID else { return }
                    displayedChapterID = activeChapterID
                }
            } else {
                CommonEmptyView("audioBook.error.library".localized, systemImage: "waveform")
            }
        }
        .toast(message: viewModel.toastMessage)
    }
    
}
