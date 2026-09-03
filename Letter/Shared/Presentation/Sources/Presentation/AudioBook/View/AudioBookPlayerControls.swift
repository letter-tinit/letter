import SwiftUI
import Domain
import Utility
import Styleguide

struct AudioBookPlayerControls: View {
    @Environment(AudioBookViewModel.self) private var viewModel
    @Environment(SpeechProviderSettingsViewModel.self) private var speechSettings
    let book: Book
    let chapter: BookChapter
    @State private var scrubProgress = 0.0
    @State private var isScrubbing = false
    private let rates = (2...12).map { Double($0) / 4 }

    var body: some View {
        VStack(spacing: 16) {
            AudioBookPlayerTitle(book: book, chapter: chapter)
            if let error = viewModel.errorMessage {
                Label(error, systemImage: "exclamationmark.triangle.fill").font(.caption).foregroundStyle(.orange)
            }
            AudioBookPlaybackProgress(value: playbackProgress, isEnabled: isActive) { editing in
                isScrubbing = editing
                if !editing { viewModel.seek(to: scrubProgress) }
            } setValue: { scrubProgress = $0 }
            AudioBookTransportControls(bookID: book.id, chapterID: chapter.id)
            AudioBookRatePicker(rates: rates, isEnabled: isActive)
            if speechSettings.selectedProvider == .googleCloud { GoogleCloudPlayerVoicePicker(book: book) }
            if speechSettings.selectedProvider == .offline { OfflinePlayerVoicePicker(book: book) }
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
            Text(book.title).font(.caption).foregroundStyle(.secondary)
            Text(chapter.displayTitle).font(.headline).lineLimit(1)
        }
    }
}

struct AudioBookPlaybackProgress: View {
    let value: Double
    let isEnabled: Bool
    let onEditingChanged: (Bool) -> Void
    let setValue: (Double) -> Void
    var body: some View {
        VStack(spacing: 8) {
            Slider(value: Binding(get: { value }, set: setValue), in: 0...1, onEditingChanged: onEditingChanged)
                .accessibilityLabel("audioBook.seek".localized)
                .disabled(!isEnabled)
            HStack {
                Text("\(Int(value * 100))%")
                Spacer()
                Label("audioBook.backgroundPlayback".localized, systemImage: "lock.iphone")
            }
            .font(.caption).foregroundStyle(.secondary)
        }
    }
}

struct AudioBookTransportControls: View {
    @Environment(AudioBookViewModel.self) private var viewModel
    let bookID: UUID
    let chapterID: UUID
    private var isActive: Bool { viewModel.isActive(bookID: bookID, chapterID: chapterID) }
    var body: some View {
        HStack(spacing: 18) {
            Button { viewModel.moveToPreviousChapter() } label: { Image(systemName: "backward.end.fill") }
                .disabled(!isActive || !viewModel.canMoveToPreviousChapter).accessibilityLabel("audioBook.previousChapter".localized)
            Button { viewModel.skip(seconds: -15) } label: { Image(systemName: "gobackward.15") }.disabled(!isActive)
            Button { viewModel.togglePlayback(bookID: bookID, chapterID: chapterID) } label: {
                Image(systemName: viewModel.isPlaying && !viewModel.isPaused ? "pause.circle.fill" : "play.circle.fill").font(.system(size: 54))
            }
            Button { viewModel.skip(seconds: 15) } label: { Image(systemName: "goforward.15") }.disabled(!isActive)
            Button { viewModel.moveToNextChapter() } label: { Image(systemName: "forward.end.fill") }
                .disabled(!isActive || !viewModel.canMoveToNextChapter).accessibilityLabel("audioBook.nextChapter".localized)
        }
        .font(.title2).buttonStyle(.plain)
    }
}

struct AudioBookRatePicker: View {
    @Environment(AudioBookViewModel.self) private var viewModel
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

struct GoogleCloudPlayerVoicePicker: View {
    @Environment(AudioBookViewModel.self) private var viewModel
    @Environment(SpeechProviderSettingsViewModel.self) private var settings
    let book: Book
    var body: some View {
        VStack(spacing: 8) {
            AppPicker("audioBook.speechSettings.voice".localized, selection: Binding(
                get: { settings.selectedGoogleCloudVoice(for: book.language) },
                set: { settings.selectGoogleCloudVoice($0, for: book.language); viewModel.speechVoiceDidChange() }
            ), layout: .control) {
                ForEach(GoogleCloudVoicePreference.allCases, id: \.self) { Text($0.displayName(for: book.language)).tag($0) }
            }
            .pickerStyle(.menu)
            GoogleCloudUsageView(usage: settings.googleCloudUsage)
        }
    }
}

struct OfflinePlayerVoicePicker: View {
    @Environment(AudioBookViewModel.self) private var viewModel
    @Environment(SpeechProviderSettingsViewModel.self) private var settings
    let book: Book
    var body: some View {
        let model = settings.selectedOfflineModel(for: book.language)
        if !model.availableVoices.isEmpty, let voice = settings.selectedOfflineVoice(for: model) {
            AppPicker("audioBook.speechSettings.voice".localized, selection: Binding(
                get: { voice }, set: { settings.selectOfflineVoice($0, for: model); viewModel.speechVoiceDidChange() }
            ), layout: .control) {
                ForEach(model.availableVoices, id: \.self) { Text($0.rawValue).tag($0) }
            }
            .pickerStyle(.menu)
        }
    }
}
