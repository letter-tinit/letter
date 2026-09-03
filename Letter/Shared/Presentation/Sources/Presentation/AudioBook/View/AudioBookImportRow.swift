import SwiftUI
import Domain
import Utility

struct AudioBookImportRow: View {
    @Environment(AudioBookViewModel.self) private var viewModel
    let item: BookImportItem

    var body: some View {
        Button {
            if case .failed = item.state { viewModel.retryImport(id: item.id) }
        } label: {
            HStack(spacing: 14) {
                ZStack {
                    Image(systemName: "book.closed.fill").font(.title2).foregroundStyle(.tint)
                    if case .indexing = item.state {
                        RoundedRectangle(cornerRadius: 10).fill(.background.opacity(0.82))
                        ProgressView().progressViewStyle(.circular)
                    }
                }
                .frame(width: 42, height: 54)
                .background(.tint.opacity(0.12), in: RoundedRectangle(cornerRadius: 10))
                .clipShape(RoundedRectangle(cornerRadius: 10))
                VStack(alignment: .leading, spacing: 6) {
                    Text(item.title).font(.headline).lineLimit(2)
                    switch item.state {
                    case .indexing: Text("audioBook.import.indexing".localized).font(.caption).foregroundStyle(.secondary)
                    case .failed(let message):
                        Text(message).font(.caption).foregroundStyle(.red)
                        Text("audioBook.import.retry".localized).font(.caption.weight(.semibold))
                    }
                }
                Spacer()
                if case .failed = item.state { Image(systemName: "arrow.clockwise").foregroundStyle(.red) }
            }
            .padding(.vertical, 4)
        }
        .buttonStyle(.plain)
        .disabled({ if case .indexing = item.state { true } else { false } }())
    }
}
