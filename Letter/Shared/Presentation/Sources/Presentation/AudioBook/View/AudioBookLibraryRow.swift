import SwiftUI
import Domain
import Utility
import Styleguide

struct AudioBookRow: View {
    let book: Book
    let bookmarkCount: Int
    let onOpen: () -> Void
    let onBookmarks: () -> Void
    private let rowShape = RoundedRectangle(cornerRadius: 16)
    
    private var hasBookmark: Bool {
        bookmarkCount > 0
    }

    var body: some View {
        Button(action: onOpen) {
            HStack(spacing: 14) {
                AudioBookCoverView(coverData: book.coverData)
                VStack(alignment: .leading, spacing: 6) {
                    Text(book.title).customFont(.headline).lineLimit(2)
                    Text(String(format: "audioBook.library.metadata".localized, book.format.displayName, book.chapters.count))
                        .customFont(.caption)
                        .foregroundStyle(.secondary)
                    if book.readingProgress > 0 { ProgressView(value: book.readingProgress).tint(.accentColor) }
                }
                .padding(.top, hasBookmark ? 32 : 0)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding()
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(rowShape)
        }
        .buttonStyle(.plain)
        .appGlassEffect(.regular.interactive(), in: rowShape)
        .overlay(alignment: .topTrailing) {
            if hasBookmark {
                Button(action: onBookmarks) {
                    HStack(spacing: 6) {
                        Text(bookmarkCount, format: .number)
                        Image(systemName: "bookmark.fill")
                    }
                    .customFont(.caption, weight: .semibold)
                    .foregroundStyle(.tint)
                    .padding(.horizontal, 10)
                }
                .buttonStyle(.glass)
                .accessibilityLabel("audioBook.bookmark.title".localized)
                .accessibilityValue(Text(bookmarkCount, format: .number))
                .frame(minHeight: 44)
                .padding(.trailing, 6)
                .padding(.top, 2)
            }
        }
        .movableRowShape(rowShape)
    }
}

struct AudioBookCoverView: View {
    let coverData: Data?
    
    let coverShape = RoundedRectangle(cornerRadius: 8)

    var body: some View {
        Group {
            if let coverData, let image = UIImage(data: coverData) {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
            } else {
                Image(systemName: "book.closed.fill")
                    .customFont(.title)
                    .foregroundStyle(.tint.opacity(0.88))
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(.tint.opacity(0.12))
            }
        }
        .clipShape(coverShape)
        .shadow(radius: 2, x: 1, y: 3)
        .frame(width: 60, height: 90)
    }
}
