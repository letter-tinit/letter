import SwiftUI
import Domain
import Utility
import Styleguide

public struct AudioBookPlayerScreen: View {
    @Environment(AudioBookViewModel.self) private var viewModel
    @Environment(SpeechProviderSettingsViewModel.self) private var speechSettingsViewModel
    public let bookID: UUID
    public let chapterID: UUID
    @State private var displayedChapterID: UUID

    public init(bookID: UUID, chapterID: UUID) {
        self.bookID = bookID
        self.chapterID = chapterID
        _displayedChapterID = State(initialValue: chapterID)
    }

    public var body: some View {
        if let book = viewModel.book(id: bookID),
           let chapter = book.chapters.first(where: { $0.id == displayedChapterID }) {
            BaseScreen(.constant(chapter.displayTitle)) {
                ScrollView {
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
                viewModel.openChapterForViewing(bookID: bookID, chapterID: chapterID)
            }
            .onChange(of: viewModel.activeChapterID) { _, activeChapterID in
                guard viewModel.activeBookID == bookID,
                      let activeChapterID else { return }
                displayedChapterID = activeChapterID
            }
            .task {
                while !Task.isCancelled {
                    speechSettingsViewModel.refreshUsage()
                    try? await Task.sleep(for: .seconds(2))
                }
            }
        } else {
            ContentUnavailableView("audioBook.error.library".localized, systemImage: "waveform")
        }
    }

}
