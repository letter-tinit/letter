import SwiftUI
import UniformTypeIdentifiers
import Domain
import Core
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
                            importRow(item)
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
        }
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
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

    private func importRow(_ item: BookImportItem) -> some View {
        Button {
            if case .failed = item.state { viewModel.retryImport(id: item.id) }
        } label: {
            HStack(spacing: 14) {
                ZStack {
                    Image(systemName: "book.closed.fill")
                        .font(.title2)
                        .foregroundStyle(.tint)
                    if case .indexing = item.state {
                        RoundedRectangle(cornerRadius: 10)
                            .fill(.background.opacity(0.82))
                        ProgressView()
                            .progressViewStyle(.circular)
                    }
                }
                .frame(width: 42, height: 54)
                .background(.tint.opacity(0.12), in: RoundedRectangle(cornerRadius: 10))
                .clipShape(RoundedRectangle(cornerRadius: 10))
                VStack(alignment: .leading, spacing: 6) {
                    Text(item.title).font(.headline).lineLimit(2)
                    switch item.state {
                    case .indexing:
                        Text("audioBook.import.indexing".localized)
                            .font(.caption).foregroundStyle(.secondary)
                    case .failed(let message):
                        Text(message).font(.caption).foregroundStyle(.red)
                        Text("audioBook.import.retry".localized)
                            .font(.caption.weight(.semibold))
                    }
                }
                Spacer()
                if case .failed = item.state {
                    Image(systemName: "arrow.clockwise").foregroundStyle(.red)
                }
            }
            .padding(.vertical, 4)
        }
        .buttonStyle(.plain)
        .disabled({ if case .indexing = item.state { true } else { false } }())
    }
}

private struct AudioBookRow: View {
    public let book: Book

    public var body: some View {
        HStack(spacing: 14) {
            Group {
                if let coverData = book.coverData, let image = UIImage(data: coverData) {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFill()
                } else {
                    Image(systemName: "book.closed.fill")
                        .font(.title2)
                        .foregroundStyle(.tint)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .background(.tint.opacity(0.12))
                }
            }
            .frame(width: 42, height: 54)
            .clipShape(RoundedRectangle(cornerRadius: 10))

            VStack(alignment: .leading, spacing: 6) {
                Text(book.title)
                    .font(.headline)
                    .lineLimit(2)
                Text(
                    String(
                        format: "audioBook.library.metadata".localized,
                        book.format.displayName,
                        book.chapters.count
                    )
                )
                .font(.caption)
                .foregroundStyle(.secondary)
                if book.readingProgress > 0 {
                    ProgressView(value: book.readingProgress)
                        .tint(.accentColor)
                }
            }
        }
        .padding(.vertical, 4)
    }
}

private extension BookFormat {
    public var displayName: String { rawValue.uppercased() }
}

