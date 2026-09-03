import SwiftUI
import Domain
import Utility
import Styleguide

public struct AudioBookDetailScreen: View {
    @Environment(AudioBookViewModel.self) private var viewModel
    @State private var detailViewModel = AudioBookDetailViewModel()
    @State private var isShowingAudioExportSelection = false
    public let bookID: UUID

    public var body: some View {
        if let book = viewModel.book(id: bookID) {
            BaseScreen(.constant(book.title)) {
                List {
                    Section {
                        AudioBookDetailMetadata(book: book)
                        AudioBookExportStatusView(
                            isExporting: viewModel.isExportingAudio,
                            progress: viewModel.audioExportProgress,
                            errorMessage: viewModel.audioExportErrorMessage
                        )
                    }

                    Section("audioBook.chapters".localized) {
                        AudioBookChapterGroups(book: book, detailViewModel: detailViewModel)
                    }
                }
                .scrollContentBackground(.hidden)
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
                        viewModel.exportBookAudio(bookID: book.id, chapterIDs: chapterIDs)
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
}
