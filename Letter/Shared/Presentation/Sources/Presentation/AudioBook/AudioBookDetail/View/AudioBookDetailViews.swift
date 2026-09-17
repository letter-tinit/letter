import SwiftUI
import Domain
import Utility
import Styleguide

struct AudioBookDetailMetadata: View {
    let book: Book

    var body: some View {
        LabeledContent("audioBook.format".localized, value: book.format.rawValue.uppercased())
        LabeledContent("audioBook.chapterCount".localized, value: "\(book.chapters.count)")
    }
}

struct AudioBookChapterGroups: View {
    let book: Book
    @Binding var expandedGroupIDs: Set<UUID>
    let searchText: String

    var body: some View {
        ForEach(filteredGroups) { group in
            if let title = group.title {
                DisclosureGroup(isExpanded: expansionBinding(for: group.id)) {
                    AudioBookChapterRows(bookID: book.id, chapters: group.chapters)
                } label: {
                    Text(title).customFont(.headline)
                }
            } else {
                AudioBookChapterRows(bookID: book.id, chapters: group.chapters)
            }
        }
    }

    private var filteredGroups: [BookChapterGroup] {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return book.chapterGroups }
        let normalizedQuery = normalize(query)
        return book.chapterGroups.compactMap { group in
            let chapters = group.chapters.filter {
                normalize($0.displayTitle).localizedStandardContains(normalizedQuery)
            }
            guard !chapters.isEmpty else { return nil }
            return BookChapterGroup(id: group.id, title: group.title, chapters: chapters)
        }
    }

    private func normalize(_ value: String) -> String {
        value.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current)
    }

    private func expansionBinding(for id: UUID) -> Binding<Bool> {
        Binding(
            get: { expandedGroupIDs.contains(id) || !searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty },
            set: { isExpanded in
                if isExpanded {
                    expandedGroupIDs.insert(id)
                } else {
                    expandedGroupIDs.remove(id)
                }
            }
        )
    }
}

struct AudioBookChapterRows: View {
    let bookID: UUID
    let chapters: [BookChapter]

    var body: some View {
        ForEach(chapters) { AudioBookChapterRow(bookID: bookID, chapter: $0) }
    }
}

struct AudioBookChapterRow: View {
    @Environment(AudioBookRouter.self) private var router
    let bookID: UUID
    let chapter: BookChapter

    var body: some View {
        Button {
            router.push(.player(bookID: bookID, chapterID: chapter.id))
        } label: {
            VStack(alignment: .leading, spacing: 5) {
                Text(chapter.displayTitle).customFont(.headline)
                Text(String(format: "audioBook.chapter.characters".localized, chapter.characterCount))
                    .customFont(.caption).foregroundStyle(.secondary)
            }
            .padding(.vertical, 4)
        }
        .buttonStyle(.plain)
    }
}
