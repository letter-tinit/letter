import SwiftUI
import Domain
import Utility

struct AudioBookRow: View {
    let book: Book

    var body: some View {
        HStack(spacing: 14) {
            AudioBookCoverView(coverData: book.coverData)
            VStack(alignment: .leading, spacing: 6) {
                Text(book.title).font(.headline).lineLimit(2)
                Text(String(format: "audioBook.library.metadata".localized, book.format.displayName, book.chapters.count))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                if book.readingProgress > 0 { ProgressView(value: book.readingProgress).tint(.accentColor) }
            }
        }
        .padding(.vertical, 4)
    }
}

struct AudioBookCoverView: View {
    let coverData: Data?

    var body: some View {
        Group {
            if let coverData, let image = UIImage(data: coverData) {
                Image(uiImage: image).resizable().scaledToFill()
            } else {
                Image(systemName: "book.closed.fill")
                    .font(.title2).foregroundStyle(.tint)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(.tint.opacity(0.12))
            }
        }
        .frame(width: 42, height: 54)
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }
}
