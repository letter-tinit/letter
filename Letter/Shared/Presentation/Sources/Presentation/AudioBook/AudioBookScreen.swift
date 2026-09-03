import SwiftUI
import UniformTypeIdentifiers
import Domain
import Utility
import Styleguide

public struct AudioBookScreen: View {
    @Environment(AudioBookViewModel.self) private var viewModel
    @State private var isImporting = false

    public var body: some View {
        BaseScreen(.constant("audioBook.tab.title".localized)) {
            Group {
                if viewModel.books.isEmpty && viewModel.importItems.isEmpty {
                    ContentUnavailableView(
                        "audioBook.library.empty.title".localized,
                        systemImage: "books.vertical",
                        description: Text("audioBook.library.empty.message".localized)
                    )
                } else {
                    List {
                        ForEach(viewModel.importItems) { item in
                            AudioBookImportRow(item: item)
                        }
                        if let errorMessage = viewModel.errorMessage {
                            Text(errorMessage)
                                .foregroundStyle(.red)
                                .font(.footnote)
                        }

                        ForEach(viewModel.books) { book in
                            NavigationLink {
                                AudioBookDetailScreen(bookID: book.id)
                            } label: {
                                AudioBookRow(book: book)
                            }
                            .swipeActions {
                                Button(role: .destructive) {
                                    viewModel.deleteBook(id: book.id)
                                } label: {
                                    Label("common.delete".localized, systemImage: "trash")
                                }
                            }
                        }
                    }
                    .scrollContentBackground(.hidden)
                }
            }
            .safeAreaInset(edge: .bottom) {
                AudioBookMiniPlayer()
            }
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
    }

}
extension BookFormat {
    var displayName: String { rawValue.uppercased() }
}
