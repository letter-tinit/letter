import SwiftUI
import Utility
import Styleguide

struct AudioBookMiniPlayer: View {
    @Environment(AudioBookViewModel.self) private var viewModel
    private let rates = (2...12).map { Double($0) / 4 }

    var body: some View {
        if let playback = viewModel.activePlayback {
            VStack(spacing: 10) {
                HStack(spacing: 12) {
                    NavigationLink {
                        AudioBookPlayerScreen(
                            bookID: playback.bookID,
                            chapterID: playback.chapterID
                        )
                    } label: {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(playback.bookTitle)
                                .customFont(.caption)
                                .lineLimit(1)

                            Text(playback.chapterTitle).customFont(.subheadline, weight: .semibold).lineLimit(1)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .buttonStyle(.plain)

                    Button { viewModel.togglePlayback() } label: {
                        Image(systemName: viewModel.isPlaying && !viewModel.isPaused ? "pause.fill" : "play.fill")
                            .frame(width: 36, height: 36)
                    }
                    .buttonStyle(.glass)
                }

                Slider(
                    value: Binding(
                        get: { viewModel.playbackProgress },
                        set: { viewModel.seek(to: $0) }
                    ),
                    in: 0...1
                )
                .accessibilityLabel("audioBook.seek".localized)

                HStack {
                    AudioBookMediaTimeLabel(
                        progress: viewModel.playbackProgress,
                        characterCount: playback.chapterCharacterCount,
                        readingRate: viewModel.readingRate
                    )

                    Spacer()

                    AppPicker(
                        "audioBook.playbackSpeed".localized,
                        selection: Binding(
                            get: { viewModel.readingRate },
                            set: { viewModel.setReadingRate($0) }
                        ),
                        layout: .control
                    ) {
                        ForEach(rates, id: \.self) { rate in
                            Text(rate.formatted(.number.precision(.fractionLength(0...2))) + "×").tag(rate)
                        }
                    }
                    .labelsHidden()
                    .pickerStyle(.menu)
                }
                .customFont(.caption)
            }
            .padding()
            .cardStyle(.Glass.mint)
            .padding()
        }
    }
}
