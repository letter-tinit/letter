import SwiftUI
import Domain
import Utility
import Styleguide

struct AudioBookDetailMetadata: View {
    @Environment(AudioBookRouter.self) private var router
    let book: Book

    var body: some View {
        LabeledContent("audioBook.format".localized, value: book.format.rawValue.uppercased())
        LabeledContent("audioBook.chapterCount".localized, value: "\(book.chapters.count)")
        if book.readingProgress > 0 {
            if let chapterID = resumeChapterID {
                Button {
                    router.push(.player(bookID: book.id, chapterID: chapterID))
                } label: {
                    AudioBookReadingProgressView(progress: book.readingProgress)
                }
                .buttonStyle(.plain)
            } else {
                AudioBookReadingProgressView(progress: book.readingProgress)
            }
        }
    }

    private var resumeChapterID: UUID? {
        book.lastPosition?.chapterID ?? book.furthestPosition?.chapterID
    }
}

struct AudioBookReadingProgressView: View {
    let progress: Double

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("audioBook.progress".localized)
                Spacer()
                Text("\(Int(progress * 100))%")
                    .foregroundStyle(.secondary)
            }
            ProgressView(value: progress)
        }
        .contentShape(Rectangle())
    }

}

struct AudioBookExportStatusView: View {
    let isExporting: Bool
    let progress: Double

    var body: some View {
        if isExporting {
            VStack(alignment: .leading, spacing: 8) {
                ProgressView(value: progress)
                Text(String(format: "audioBook.export.progress".localized, Int(progress * 100)))
                    .customFont(.caption).foregroundStyle(.secondary)
            }
            .accessibilityElement(children: .combine)
        }
    }
}

struct AudioBookChapterGroups: View {
    let book: Book
    @Binding var expandedGroupIDs: Set<UUID>

    var body: some View {
        ForEach(book.chapterGroups) { group in
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

    private func expansionBinding(for id: UUID) -> Binding<Bool> {
        Binding(
            get: { expandedGroupIDs.contains(id) },
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
