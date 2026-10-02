import SwiftUI
import Domain
import Styleguide

struct AudioBookChapterTextView: View {
    let content: String
    let activeOffset: Int?
    let bookmarks: [BookBookmark]
    let scrollOffset: Int?
    private let policy = BookPassagePolicy()

    private var passages: [BookPassage] { policy.passages(in: content) }
    private var activeID: Int? {
        activeOffset.flatMap { policy.passage(at: $0, in: passages)?.id }
    }
    private var targetID: Int? {
        scrollOffset.flatMap { policy.passage(at: $0, in: passages)?.id }
    }

    var body: some View {
        ScrollViewReader { proxy in
            LazyVStack(alignment: .leading, spacing: 14) {
                ForEach(passages) { passage in
                    passageView(passage)
                        .id(passage.id)
                }
            }
            .textSelection(.enabled)
            .padding(.horizontal)
            .padding(.vertical, 12)
            .padding(.bottom, 48)
            .onChange(of: activeID) { _, id in
                guard let id else { return }
                withAnimation(.smooth(duration: 0.35)) { proxy.scrollTo(id, anchor: .center) }
            }
            .onChange(of: targetID, initial: true) { _, id in
                guard let id else { return }
                proxy.scrollTo(id, anchor: .center)
            }
        }
    }

    private func passageView(_ passage: BookPassage) -> some View {
        let isReading = passage.id == activeID
        let isSaved = bookmarks.contains { $0.position.characterOffset == passage.range.lowerBound }
        return Text(passage.text)
            .customFont(.title3)
            .lineSpacing(7)
            .foregroundStyle(.primary)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, isReading || isSaved ? 12 : 0)
            .padding(.vertical, isReading || isSaved ? 8 : 0)
            .background {
                RoundedRectangle(cornerRadius: 12)
                    .fill(isSaved ? Color.yellow.opacity(0.2) : isReading ? Color.accentColor.opacity(0.16) : Color.clear)
            }
            .overlay {
                if isSaved && isReading {
                    RoundedRectangle(cornerRadius: 12).stroke(Color.accentColor, lineWidth: 2)
                }
            }
    }
}
