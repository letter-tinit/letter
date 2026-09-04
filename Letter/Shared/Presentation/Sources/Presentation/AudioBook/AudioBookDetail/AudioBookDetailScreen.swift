import SwiftUI
import Domain
import Utility
import Styleguide

public struct AudioBookDetailScreen: View {
    @State private var viewModel: AudioBookDetailViewModel
    @State private var expandedGroupIDs: Set<UUID> = []
    @State private var isShowingAudioExportSelection = false
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
                        AudioBookExportStatusView(
                            isExporting: viewModel.isExportingAudio,
                            progress: viewModel.audioExportProgress
                        )
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
                .toolbar {
                    ToolbarItem(placement: .primaryAction) {
                        if viewModel.isExportingAudio {
                            Button(role: .cancel) {
                                viewModel.cancelAudioExport()
                            } label: {
                                Label("audioBook.export.cancel".localized, systemImage: "xmark.circle")
                            }
                        } else {
                            Button {
                                isShowingAudioExportSelection = true
                            } label: {
                                Label("audioBook.export".localized, systemImage: "square.and.arrow.up")
                            }
                        }
                    }
                }
                .sheet(isPresented: $isShowingAudioExportSelection) {
                    AudioExportChapterSelectionSheet(book: book) { chapterIDs in
                        viewModel.exportAudio(chapterIDs: chapterIDs)
                    }
                }
                .sheet(
                    item: Binding(
                        get: { viewModel.exportedAudioFile },
                        set: { item in
                            if item == nil { viewModel.clearExportedAudio() }
                        }
                    )
                ) { file in
                    AudioFileShareSheet(url: file.url)
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
