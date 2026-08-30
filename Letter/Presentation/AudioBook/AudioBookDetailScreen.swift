import SwiftUI

struct AudioBookDetailScreen: View {
    @Environment(AudioBookViewModel.self) private var viewModel
    @State private var expandedGroupIDs: Set<UUID> = []
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
                        ForEach(book.chapterGroups) { group in
                            if let title = group.title {
                                DisclosureGroup(
                                    isExpanded: Binding(
                                        get: { expandedGroupIDs.contains(group.id) },
                                        set: { isExpanded in
                                            if isExpanded {
                                                expandedGroupIDs.insert(group.id)
                                            } else {
                                                expandedGroupIDs.remove(group.id)
                                            }
                                        }
                                    )
                                ) {
                                    ForEach(group.chapters) { chapter in
                                        chapterLink(bookID: book.id, chapter: chapter)
                                    }
                                } label: {
                                    Text(title).font(.headline)
                                }
                            } else {
                                ForEach(group.chapters) { chapter in
                                    chapterLink(bookID: book.id, chapter: chapter)
                                }
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

    private func chapterLink(bookID: UUID, chapter: BookChapter) -> some View {
        NavigationLink {
            AudioBookPlayerScreen(bookID: bookID, chapterID: chapter.id)
        } label: {
            VStack(alignment: .leading, spacing: 5) {
                Text(chapter.displayTitle).font(.headline)
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
