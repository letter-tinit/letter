import SwiftUI
import UniformTypeIdentifiers
import Domain
import Utility
import Styleguide

public struct AudioBookScreen: View {
    @Environment(AudioBookRouter.self) private var router
    @Environment(AudioBookViewModel.self) private var viewModel
    @State private var isImporting = false
    @State private var isImportListPresentating =  false
    
    // MARK: BookList
    fileprivate func bookList() -> some View {
        return AppList {
            ForEach(viewModel.books) { book in
                Button {
                    router.push(.detail(bookID: book.id))
                } label: {
                    AudioBookRow(book: book)
                        .padding(.horizontal)
                }
                .buttonStyle(.plain)
                .swipeActions {
                    Button(role: .destructive) {
                        viewModel.deleteBook(id: book.id)
                    } label: {
                        Label("common.delete".localized, systemImage: "trash")
                    }
                }
            }
        }
        .contentMargins(.bottom, 16)
        .listRowSpacing(16)
    }
    
    // MARK: BODY
    public var body: some View {
        BaseScreen(.constant("audioBook.tab.title".localized)) {
            Group {
                if viewModel.isBookListEmpty() {
                    CommonEmptyView(
                        "audioBook.library.empty.title".localized,
                        systemImage: "books.vertical",
                        description: "audioBook.library.empty.message".localized
                    )
                } else {
                    bookList()
                }
            }
            .safeAreaInset(edge: .bottom) {
                AudioBookMiniPlayer()
            }
            .safeAreaInset(edge: .top) {
                if !viewModel.importItems.isEmpty {
                    Button {
                        isImportListPresentating = true
                    } label: {
                        Text("audioBook.import.indexing".localized)
                            .customFont(.headline)
                    }
                    .buttonStyle(.glass)
                }
            }
        }
        .sheet(isPresented: $isImportListPresentating) {
            NavigationStack {
                AudioBookIndexingSheet()
            }
            .presentationDetents([.medium, .large])
        }
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    isImporting = true
                } label: {
                    Label("audioBook.import".localized, systemImage: "plus")
                }
            }
        }
        .fileImporter(
            isPresented: $isImporting,
            allowedContentTypes: [.plainText, .rtf, .pdf, .epub],
            allowsMultipleSelection: true
        ) { result in
            guard case .success(let urls) = result else { return }
            viewModel.importDocuments(from: urls)
        }
        .toast(message: viewModel.toastMessage)
    }
}
extension BookFormat {
    var displayName: String { rawValue.uppercased() }
}
