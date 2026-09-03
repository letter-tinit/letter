import SwiftUI
import Domain
import Utility
import Styleguide

public struct AudioBookPlayerScreen: View {
    @Environment(AudioBookViewModel.self) private var viewModel
    @Environment(SpeechProviderSettingsViewModel.self) private var speechSettingsViewModel
    public let bookID: UUID
    public let chapterID: UUID
    @State private var displayedChapterID: UUID
    @State private var scrubProgress = 0.0
    @State private var isScrubbing = false

    private let rates = (2...12).map { Double($0) / 4 }

    public init(bookID: UUID, chapterID: UUID) {
        self.bookID = bookID
        self.chapterID = chapterID
        _displayedChapterID = State(initialValue: chapterID)
    }

    public var body: some View {
        if let book = viewModel.book(id: bookID),
           let chapter = book.chapters.first(where: { $0.id == displayedChapterID }) {
            BaseScreen(.constant(chapter.displayTitle)) {
                ScrollView {
                    Text(chapter.content)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .textSelection(.enabled)
                        .padding()
                }
                .safeAreaInset(edge: .bottom) {
                    player(book: book, chapter: chapter)
                        .padding()
                        .background(.ultraThinMaterial)
                }
            }
            .onAppear {
                viewModel.prepareChapter(bookID: bookID, chapterID: chapterID)
                scrubProgress = viewModel.playbackProgress
            }
            .onChange(of: viewModel.activeChapterID) { _, activeChapterID in
                guard viewModel.activeBookID == bookID,
                      let activeChapterID else { return }
                displayedChapterID = activeChapterID
                scrubProgress = viewModel.playbackProgress
            }
            .task {
                while !Task.isCancelled {
                    speechSettingsViewModel.refreshUsage()
                    try? await Task.sleep(for: .seconds(2))
                }
            }
        } else {
            ContentUnavailableView("audioBook.error.library".localized, systemImage: "waveform")
        }
    }

    private func player(book: Book, chapter: BookChapter) -> some View {
        VStack(spacing: 16) {
            VStack(spacing: 4) {
                Text(book.title)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(chapter.displayTitle)
                    .font(.headline)
                    .lineLimit(1)
            }

            if let errorMessage = viewModel.errorMessage {
                Label(errorMessage, systemImage: "exclamationmark.triangle.fill")
                    .font(.caption)
                    .foregroundStyle(.orange)
            }

            Slider(
                value: Binding(
                    get: { isScrubbing ? scrubProgress : viewModel.playbackProgress },
                    set: { scrubProgress = $0 }
                ),
                in: 0...1,
                onEditingChanged: { editing in
                    isScrubbing = editing
                    if !editing { viewModel.seek(to: scrubProgress) }
                }
            )
            .accessibilityLabel("audioBook.seek".localized)

            HStack {
                Text("\(Int((isScrubbing ? scrubProgress : viewModel.playbackProgress) * 100))%")
                Spacer()
                Label("audioBook.backgroundPlayback".localized, systemImage: "lock.iphone")
            }
            .font(.caption)
            .foregroundStyle(.secondary)

            HStack(spacing: 18) {
                Button { viewModel.moveToPreviousChapter() } label: {
                    Image(systemName: "backward.end.fill")
                }
                .disabled(!viewModel.canMoveToPreviousChapter)
                .accessibilityLabel("audioBook.previousChapter".localized)
                Button { viewModel.skip(seconds: -15) } label: {
                    Image(systemName: "gobackward.15")
                }
                Button { viewModel.togglePlayback() } label: {
                    Image(systemName: viewModel.isPlaying && !viewModel.isPaused ? "pause.circle.fill" : "play.circle.fill")
                        .font(.system(size: 54))
                }
                Button { viewModel.skip(seconds: 15) } label: {
                    Image(systemName: "goforward.15")
                }
                Button { viewModel.moveToNextChapter() } label: {
                    Image(systemName: "forward.end.fill")
                }
                .disabled(!viewModel.canMoveToNextChapter)
                .accessibilityLabel("audioBook.nextChapter".localized)
            }
            .font(.title2)
            .buttonStyle(.plain)

            AppPicker(
                "audioBook.playbackSpeed".localized,
                selection: Binding(
                    get: { viewModel.readingRate },
                    set: { viewModel.setReadingRate($0) }
                ),
                layout: .labeledRow
            ) {
                ForEach(rates, id: \.self) { rate in
                    Text(rateLabel(rate)).tag(rate)
                }
            }
            .pickerStyle(.menu)

            if speechSettingsViewModel.selectedProvider == .googleCloud {
                googleVoiceControls
            }

            if speechSettingsViewModel.selectedProvider == .offline {
                offlineVoiceControls(for: book)
            }

            Toggle(
                "audioBook.automaticChapterAdvance".localized,
                isOn: Binding(
                    get: { viewModel.automaticallyPlaysNextChapter },
                    set: { viewModel.automaticallyPlaysNextChapter = $0 }
                )
            )

        }
        .padding()
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 24))
    }

    private var googleVoiceControls: some View {
        VStack(spacing: 8) {
            AppPicker(
                "audioBook.speechSettings.voice".localized,
                selection: Binding(
                    get: { speechSettingsViewModel.selectedGoogleCloudVoice },
                    set: { voice in
                        speechSettingsViewModel.selectGoogleCloudVoice(voice)
                        viewModel.speechVoiceDidChange()
                    }
                ),
                layout: .control
            ) {
                ForEach(GoogleCloudVoicePreference.allCases, id: \.self) { voice in
                    Text(voice.localizedName).tag(voice)
                }
            }
            .pickerStyle(.menu)

            ProgressView(
                value: Double(speechSettingsViewModel.googleCloudUsage.characterCount),
                total: Double(speechSettingsViewModel.googleCloudUsage.freeCharacterLimit)
            )
            Text(
                String(
                    format: "audioBook.speechSettings.usage".localized,
                    speechSettingsViewModel.googleCloudUsage.characterCount,
                    speechSettingsViewModel.googleCloudUsage.freeCharacterLimit
                )
            )
            .font(.caption)
            .foregroundStyle(.secondary)
        }
    }

    @ViewBuilder
    private func offlineVoiceControls(for book: Book) -> some View {
        let model = speechSettingsViewModel.selectedOfflineModel(for: book.language)
        if !model.availableVoices.isEmpty,
           let selectedVoice = speechSettingsViewModel.selectedOfflineVoice(for: model) {
            AppPicker(
                "audioBook.speechSettings.voice".localized,
                selection: Binding(
                    get: { selectedVoice },
                    set: { voice in
                        speechSettingsViewModel.selectOfflineVoice(voice, for: model)
                        viewModel.speechVoiceDidChange()
                    }
                ),
                layout: .control
            ) {
                ForEach(model.availableVoices, id: \.self) { voice in
                    Text(voice.rawValue).tag(voice)
                }
            }
            .pickerStyle(.menu)
        }
    }

    private func rateLabel(_ rate: Double) -> String {
        rate.formatted(.number.precision(.fractionLength(0...2))) + "×"
    }
}
