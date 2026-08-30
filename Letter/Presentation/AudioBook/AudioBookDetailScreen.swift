import SwiftUI

struct AudioBookDetailScreen: View {
    @Environment(AudioBookViewModel.self) private var viewModel
    let bookID: UUID

    var body: some View {
        if let book = viewModel.book(id: bookID) {
            BaseScreen(.constant(book.title)) {
                List {
                    Section {
                        LabeledContent("audioBook.format".localized, value: book.format.rawValue.uppercased())
                        LabeledContent("audioBook.chapterCount".localized, value: "\(book.chapters.count)")
                        if book.readingProgress > 0 {
                            ProgressView(value: book.readingProgress) {
                                Text("audioBook.progress".localized)
                            }
                        }
                    }

                    Section("audioBook.chapters".localized) {
                        ForEach(book.chapters) { chapter in
                            NavigationLink {
                                AudioBookPlayerScreen(bookID: book.id, chapterID: chapter.id)
                            } label: {
                                VStack(alignment: .leading, spacing: 5) {
                                    Text(chapter.title)
                                        .font(.headline)
                                    Text(
                                        String(
                                            format: "audioBook.chapter.characters".localized,
                                            chapter.characterCount
                                        )
                                    )
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                }
                                .padding(.vertical, 4)
                            }
                        }
                    }
                }
                .scrollContentBackground(.hidden)
            }
        } else {
            ContentUnavailableView("audioBook.error.library".localized, systemImage: "book.closed")
        }
    }
}
