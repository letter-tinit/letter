import SwiftUI
import UniformTypeIdentifiers

struct AudioBookScreen: View {
    @Environment(AudioBookViewModel.self) private var viewModel
    @State private var isImporting = false

    var body: some View {
        BaseScreen(.constant("audioBook.tab.title".localized)) {
            Group {
                if viewModel.books.isEmpty {
                    ContentUnavailableView(
                        "audioBook.library.empty.title".localized,
                        systemImage: "books.vertical",
                        description: Text("audioBook.library.empty.message".localized)
                    )
                } else {
                    List {
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
            allowsMultipleSelection: false
        ) { result in
            guard case .success(let urls) = result, let url = urls.first else { return }
            let scoped = url.startAccessingSecurityScopedResource()
            defer { if scoped { url.stopAccessingSecurityScopedResource() } }
            viewModel.importDocument(from: url)
        }
    }
}

private struct AudioBookRow: View {
    let book: Book

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: "book.closed.fill")
                .font(.title2)
                .foregroundStyle(.tint)
                .frame(width: 42, height: 54)
                .background(.tint.opacity(0.12), in: RoundedRectangle(cornerRadius: 10))

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
    var displayName: String { rawValue.uppercased() }
}

#Preview {
    NavigationStack {
        AudioBookScreen()
            .environment(AppContainer(inMemory: true).makeAudioBookViewModel())
    }
}
