import SwiftUI
import Domain
import Utility

struct AudioBookDetailMetadata: View {
    let book: Book

    var body: some View {
        LabeledContent("audioBook.format".localized, value: book.format.rawValue.uppercased())
        LabeledContent("audioBook.chapterCount".localized, value: "\(book.chapters.count)")
        if book.readingProgress > 0 {
            ProgressView(value: book.readingProgress) { Text("audioBook.progress".localized) }
        }
    }
}

struct AudioBookExportStatusView: View {
    let isExporting: Bool
    let progress: Double
    let errorMessage: String?

    var body: some View {
        if isExporting {
            VStack(alignment: .leading, spacing: 8) {
                ProgressView(value: progress)
                Text(String(format: "audioBook.export.progress".localized, Int(progress * 100)))
                    .font(.caption).foregroundStyle(.secondary)
            }
            .accessibilityElement(children: .combine)
        }
        if let errorMessage {
            Label(errorMessage, systemImage: "exclamationmark.triangle.fill").foregroundStyle(.red)
        }
    }
}

struct AudioBookChapterGroups: View {
    let book: Book
    let detailViewModel: AudioBookDetailViewModel

    var body: some View {
        ForEach(book.chapterGroups) { group in
            if let title = group.title {
                DisclosureGroup(isExpanded: expansionBinding(for: group.id)) {
                    AudioBookChapterRows(bookID: book.id, chapters: group.chapters)
                } label: {
                    Text(title).font(.headline)
                }
            } else {
                AudioBookChapterRows(bookID: book.id, chapters: group.chapters)
            }
        }
    }

    private func expansionBinding(for id: UUID) -> Binding<Bool> {
        Binding(
            get: { detailViewModel.expandedGroupIDs.contains(id) },
            set: { isExpanded in
                detailViewModel.setGroup(id, isExpanded: isExpanded)
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
    let bookID: UUID
    let chapter: BookChapter

    var body: some View {
        NavigationLink { AudioBookPlayerScreen(bookID: bookID, chapterID: chapter.id) } label: {
            VStack(alignment: .leading, spacing: 5) {
                Text(chapter.displayTitle).font(.headline)
                Text(String(format: "audioBook.chapter.characters".localized, chapter.characterCount))
                    .font(.caption).foregroundStyle(.secondary)
            }
            .padding(.vertical, 4)
        }
    }
}
