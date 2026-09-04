import SwiftUI
import Domain
import Utility
import Styleguide

struct AudioBookPlayerControls: View {
    @Environment(AudioBookPlayerViewModel.self) private var viewModel
    let book: Book
    let chapter: BookChapter
    @State private var scrubProgress = 0.0
    @State private var isScrubbing = false
    private let rates = (2...12).map { Double($0) / 4 }

    var body: some View {
        VStack(spacing: 16) {
            AudioBookPlayerTitle(book: book, chapter: chapter)
            AudioBookPlaybackProgress(
                value: playbackProgress,
                characterCount: chapter.characterCount,
                readingRate: viewModel.readingRate,
                isEnabled: isActive
            ) { editing in
                isScrubbing = editing
                if !editing { viewModel.seek(to: scrubProgress) }
            } setValue: { scrubProgress = $0 }
            AudioBookTransportControls(bookID: book.id, chapterID: chapter.id)
            AudioBookRatePicker(rates: rates, isEnabled: isActive)
            Toggle("audioBook.automaticChapterAdvance".localized, isOn: Binding(
                get: { viewModel.automaticallyPlaysNextChapter },
                set: { viewModel.automaticallyPlaysNextChapter = $0 }
            ))
        }
        .padding()
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 24))
    }

    private var isActive: Bool { viewModel.isActive(bookID: book.id, chapterID: chapter.id) }
    private var playbackProgress: Double {
        isScrubbing ? scrubProgress : viewModel.playbackProgress(for: book, chapter: chapter)
    }
}

struct AudioBookPlayerTitle: View {
    let book: Book
    let chapter: BookChapter
    var body: some View {
        VStack(spacing: 4) {
            Text(book.title).customFont(.caption).foregroundStyle(.secondary)
            Text(chapter.displayTitle).customFont(.headline).lineLimit(1)
        }
    }
}

struct AudioBookPlaybackProgress: View {
    let value: Double
    let characterCount: Int
    let readingRate: Double
    let isEnabled: Bool
    let onEditingChanged: (Bool) -> Void
    let setValue: (Double) -> Void
    var body: some View {
        VStack(spacing: 8) {
            Slider(value: Binding(get: { value }, set: setValue), in: 0...1, onEditingChanged: onEditingChanged)
                .accessibilityLabel("audioBook.seek".localized)
                .disabled(!isEnabled)
            HStack {
                AudioBookMediaTimeLabel(
                    progress: value,
                    characterCount: characterCount,
                    readingRate: readingRate
                )
                Spacer()
                Label("audioBook.backgroundPlayback".localized, systemImage: "lock.iphone")
            }
            .customFont(.caption).foregroundStyle(.secondary)
        }
    }
}

struct AudioBookMediaTimeLabel: View {
    let progress: Double
    let characterCount: Int
    let readingRate: Double

    var body: some View {
        Text("\(formattedTime(currentSeconds)) / \(formattedTime(totalSeconds))")
            .monospacedDigit()
    }

    private var totalSeconds: Int {
        max(1, Int((Double(characterCount) / (14 * readingRate)).rounded(.up)))
    }

    private var currentSeconds: Int {
        min(totalSeconds, Int((Double(totalSeconds) * progress).rounded(.down)))
    }

    private func formattedTime(_ seconds: Int) -> String {
        let hours = seconds / 3_600
        let minutes = seconds % 3_600 / 60
        let remainingSeconds = seconds % 60
        if hours > 0 {
            return "\(hours):\(String(format: "%02d", minutes)):\(String(format: "%02d", remainingSeconds))"
        }
        return "\(minutes):\(String(format: "%02d", remainingSeconds))"
    }
}

struct AudioBookTransportControls: View {
    @Environment(AudioBookPlayerViewModel.self) private var viewModel
    let bookID: UUID
    let chapterID: UUID
    private var isActive: Bool { viewModel.isActive(bookID: bookID, chapterID: chapterID) }
    var body: some View {
        HStack(spacing: 18) {
            Button { viewModel.moveToPreviousChapter() } label: { Image(systemName: "backward.end.fill") }
                .disabled(!isActive || !viewModel.canMoveToPreviousChapter).accessibilityLabel("audioBook.previousChapter".localized)
            Button { viewModel.skip(seconds: -15) } label: { Image(systemName: "gobackward.15") }.disabled(!isActive)
            Button { viewModel.togglePlayback(bookID: bookID, chapterID: chapterID) } label: {
                Image(systemName: viewModel.isPlaying && !viewModel.isPaused ? "pause.circle.fill" : "play.circle.fill").customFont(size: 54)
            }
            Button { viewModel.skip(seconds: 15) } label: { Image(systemName: "goforward.15") }.disabled(!isActive)
            Button { viewModel.moveToNextChapter() } label: { Image(systemName: "forward.end.fill") }
                .disabled(!isActive || !viewModel.canMoveToNextChapter).accessibilityLabel("audioBook.nextChapter".localized)
        }
        .customFont(.title2).buttonStyle(.plain)
    }
}

struct AudioBookRatePicker: View {
    @Environment(AudioBookPlayerViewModel.self) private var viewModel
    let rates: [Double]
    let isEnabled: Bool
    var body: some View {
        AppPicker("audioBook.playbackSpeed".localized, selection: Binding(
            get: { viewModel.readingRate }, set: { viewModel.setReadingRate($0) }
        ), layout: .labeledRow) {
            ForEach(rates, id: \.self) { Text($0.formatted(.number.precision(.fractionLength(0...2))) + "×").tag($0) }
        }
        .pickerStyle(.menu)
        .disabled(!isEnabled)
    }
}
