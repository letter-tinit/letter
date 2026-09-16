import SwiftUI
import Domain
import Utility
import Styleguide

struct AudioBookImportRow: View {
    @Environment(AudioBookViewModel.self) private var viewModel
    let item: BookImportItem
    
    var body: some View {
        HStack(spacing: 14) {
            ZStack {
                Group {
                    switch item.state {
                    case .indexing:
                        Image(systemName: "book.closed.fill")
                    case .failed:
                        Button {
                            viewModel.retryImport(id: item.id)
                        } label: {
                            Image(systemName: "arrow.clockwise")
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .frame(width: 50, height: 70)
            .foregroundStyle(.tint)
            .background(.tint.opacity(0.12), in: RoundedRectangle(cornerRadius: 10))
            .clipShape(RoundedRectangle(cornerRadius: 10))
            
            VStack(alignment: .leading, spacing: 6) {
                Text(item.title).customFont(.headline).lineLimit(2)
                switch item.state {
                case .indexing: Text("audioBook.import.indexing".localized).customFont(.caption).foregroundStyle(.secondary)
                case .failed(let message):
                    Text(message).customFont(.caption).foregroundStyle(.red)
                }
            }
            
            Spacer()
            
            switch item.state {
            case .indexing:
                Button {
                    viewModel.cancelImport(id: item.id)
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .customFont(.title3)
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
                
            case .failed:
                Button {
                    viewModel.removeImport(id: item.id)
                } label: {
                    Image(systemName: "trash.circle.fill")
                        .customFont(.title3)
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.vertical, 4)
    }
}
