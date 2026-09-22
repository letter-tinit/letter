import SwiftUI
import UniformTypeIdentifiers
import Domain
import Utility
import Styleguide

public struct AudioBookScreen: View {
    @Environment(AudioBookRouter.self) private var router
    @Environment(AudioBookViewModel.self) private var viewModel
    @Environment(AudioBookPlayerViewModel.self) private var playerViewModel
    @State private var model = AudioBookScreenModel()
    
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
                .swipeActions(allowsFullSwipe: false) {
                    Button {
                        do {
                            try playerViewModel.resetBook(id: book.id)
                            viewModel.reloadBooks()
                            model.resetToast = ToastMessage(text: "audioBook.reset.success".localized, type: .success)
                        } catch {
                            model.resetToast = ToastMessage(text: "audioBook.reset.failure".localized, type: .failure)
                        }
                    } label: {
                        Label("audioBook.reset".localized, systemImage: "arrow.counterclockwise")
                    }
                    .tint(.orange)
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
            .safeAreaInset(edge: .top) {
                if !viewModel.importItems.isEmpty {
                    Button {
                        model.isImportListPresenting = true
                    } label: {
                        Text("audioBook.import.indexing".localized)
                            .customFont(.headline)
                    }
                    .buttonStyle(.glass)
                }
            }
        }
        .sheet(isPresented: $model.isImportListPresenting) {
            NavigationStack {
                AudioBookIndexingSheet()
            }
            .presentationDetents([.medium, .large])
        }
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    model.isImporting = true
                } label: {
                    Label("audioBook.import".localized, systemImage: "plus")
                }
            }
        }
        .fileImporter(
            isPresented: $model.isImporting,
            allowedContentTypes: [.plainText, .markdownText, .rtf, .pdf, .epub],
            allowsMultipleSelection: true
        ) { result in
            guard case .success(let urls) = result else { return }
            viewModel.importDocuments(from: urls)
        }
        .toast(message: viewModel.toastMessage)
        .toast(message: model.resetToast)
    }
}

struct AudioBookScreenModel {
    var resetToast: ToastMessage?
    var isImporting = false
    var isImportListPresenting = false
}

extension BookFormat {
    var displayName: String {
        switch self {
        case .markdown:
            "MD"
        default:
            rawValue.uppercased()
        }
    }
}

private extension UTType {
    static var markdownText: UTType {
        UTType(filenameExtension: "md") ?? .plainText
    }
}
