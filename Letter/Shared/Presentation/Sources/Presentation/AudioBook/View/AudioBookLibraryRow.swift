import SwiftUI
import Domain
import Utility
import Styleguide

struct AudioBookRow: View {
    let book: Book

    var body: some View {
        HStack(spacing: 14) {
            AudioBookCoverView(coverData: book.coverData)
            
            VStack(alignment: .leading, spacing: 6) {
                Text(book.title).customFont(.headline).lineLimit(2)
                Text(String(format: "audioBook.library.metadata".localized, book.format.displayName, book.chapters.count))
                    .customFont(.caption)
                    .foregroundStyle(.secondary)
                if book.readingProgress > 0 { ProgressView(value: book.readingProgress).tint(.accentColor) }
            }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .appGlassEffect(
            .regular.interactive()
        )
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
