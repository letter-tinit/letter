import SwiftUI
import Domain
import Utility
import Styleguide

public struct AudioBookPlayerScreen: View {
    @Environment(AudioBookRouter.self) private var router
    @Environment(AudioBookPlayerViewModel.self) private var viewModel
    @Binding private var book: Book?
    public let chapterID: UUID
    @State private var displayedChapterID: UUID
    @State private var isPlayerPresented = false
    @State private var hasPresentedPlayer = false
    @State private var isLongTextMode = false
    @State private var playerDetent = AudioBookPlayerSheetDetent.collapsed
    
    public init(book: Binding<Book?>, chapterID: UUID) {
        _book = book
        self.chapterID = chapterID
        _displayedChapterID = State(initialValue: chapterID)
    }
    
    public var body: some View {
        Group {
            if let book,
               let chapter = book.chapters.first(where: { $0.id == displayedChapterID }) {
                BaseScreen(.constant(chapter.displayTitle)) {
                    AppScrollView {
                        AudioBookChapterTextView(
                            content: chapter.content,
                            playbackProgress: viewModel.playbackProgress(for: book, chapter: chapter),
                            isHighlightingEnabled: viewModel.isActive(bookID: book.id, chapterID: chapter.id),
                            isLongTextMode: isLongTextMode
                        )
                    }
                }
                .onAppear {
                    viewModel.openChapterForViewing(bookID: book.id, chapterID: chapterID)
                    presentPlayerIfNeeded()
                }
                .onChange(of: viewModel.activeChapterID) { _, activeChapterID in
                    guard viewModel.activeBookID == book.id,
                          let activeChapterID else { return }
                    displayedChapterID = activeChapterID
                }
                .onChange(of: router.path) { _, path in
                    guard !path.contains(.player(bookID: book.id, chapterID: chapterID)) else { return }
                    dismissPlayerForNavigation()
                }
                .sheet(isPresented: $isPlayerPresented) {
                    AudioBookPlayerPopup(book: book, chapter: chapter)
                        .presentationDetents(
                            [AudioBookPlayerSheetDetent.collapsed, .medium],
                            selection: $playerDetent
                        )
                        .presentationDragIndicator(.visible)
                        .presentationCornerRadius(28)
                        .presentationBackground(.regularMaterial)
                        .presentationBackgroundInteraction(.enabled(upThrough: .medium))
                        .interactiveDismissDisabled()
                }
                .toolbar {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button {
                            isLongTextMode.toggle()
                            if isLongTextMode {
                                isPlayerPresented = false
                            } else {
                                playerDetent = AudioBookPlayerSheetDetent.collapsed
                                isPlayerPresented = true
                            }
                        } label: {
                            Image(systemName: isLongTextMode ? "textformat.size.larger" : "text.alignleft")
                        }
                        .accessibilityLabel("audioBook.longTextMode".localized)
                    }
                }
            } else {
                CommonEmptyView("audioBook.error.library".localized, systemImage: "waveform")
            }
        }
        .toast(message: viewModel.toastMessage)
    }

    private func presentPlayerIfNeeded() {
        guard !hasPresentedPlayer, !isLongTextMode else { return }
        hasPresentedPlayer = true
        playerDetent = .medium
        isPlayerPresented = true
    }

    private func dismissPlayerForNavigation() {
        var transaction = Transaction()
        transaction.animation = .easeOut(duration: 0.12)
        withTransaction(transaction) {
            isPlayerPresented = false
        }
    }
}

private enum AudioBookPlayerSheetDetent {
    static let collapsed = PresentationDetent.height(92)
}

private struct AudioBookPlayerPopup: View {
    let book: Book
    let chapter: BookChapter

    var body: some View {
        VStack(spacing: 24) {
            AudioBookPlayerTitle(book: book, chapter: chapter)
                .padding(.top, 6)

            AudioBookPlayerControls(book: book, chapter: chapter, showsTitle: false)
        }
        .padding(.horizontal, 20)
        .padding(.top, 10)
        .padding(.bottom, 26)
    }
}

private struct AudioBookChapterTextView: View {
    let content: String
    let playbackProgress: Double
    let isHighlightingEnabled: Bool
    let isLongTextMode: Bool

    private var segments: [AudioBookTextSegment] {
        AudioBookTextSegment.segments(in: content)
    }

    private var activeOffset: Int {
        let clampedProgress = min(max(playbackProgress, 0), 1)
        return Int((Double(content.count) * clampedProgress).rounded(.down))
    }

    private var activeSegmentID: Int? {
        guard isHighlightingEnabled, !isLongTextMode else { return nil }
        return segments.first { $0.range.contains(activeOffset) }?.id
    }

    var body: some View {
        ScrollViewReader { proxy in
            LazyVStack(alignment: .leading, spacing: isLongTextMode ? 10 : 14) {
                ForEach(segments) { segment in
                    Text(segment.text)
                        .customFont(isLongTextMode ? .body : .title3)
                        .lineSpacing(isLongTextMode ? 4 : 7)
                        .foregroundStyle(.primary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, isActive(segment) ? 12 : 0)
                        .padding(.vertical, isActive(segment) ? 8 : 0)
                        .background {
                            if isActive(segment) {
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(Color.accentColor.opacity(0.16))
                            }
                        }
                        .id(segment.id)
                        .animation(.smooth(duration: 0.2), value: activeOffset)
                }
            }
            .textSelection(.enabled)
            .padding(.horizontal)
            .padding(.vertical, 12)
            .padding(.bottom, isLongTextMode ? 8 : 48)
            .onChange(of: activeSegmentID) { _, segmentID in
                guard let segmentID else { return }
                withAnimation(.smooth(duration: 0.35)) {
                    proxy.scrollTo(segmentID, anchor: .center)
                }
            }
        }
    }

    private func isActive(_ segment: AudioBookTextSegment) -> Bool {
        isHighlightingEnabled &&
        !isLongTextMode &&
        segment.range.contains(activeOffset)
    }
}

private struct AudioBookTextSegment: Identifiable {
    let id: Int
    let text: String
    let range: Range<Int>

    static func segments(in content: String) -> [AudioBookTextSegment] {
        var offset = 0
        return content
            .components(separatedBy: CharacterSet.newlines)
            .map { paragraph in
                let trimmed = paragraph.trimmingCharacters(in: .whitespacesAndNewlines)
                let start = offset
                offset += paragraph.count + 1
                return (text: trimmed, range: start..<max(start + trimmed.count, start + 1))
            }
            .filter { !$0.text.isEmpty }
            .enumerated()
            .map { index, element in
                AudioBookTextSegment(id: index, text: element.text, range: element.range)
            }
    }
}
