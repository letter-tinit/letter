import SwiftUI
import Utility
import Styleguide

struct AudioBookMiniPlayer: View {
    @Environment(AudioBookRouter.self) private var router
    @Environment(AudioBookPlayerViewModel.self) private var viewModel
    let bookID: UUID

    var body: some View {
        if let playback = viewModel.latestPlayback(for: bookID) {
            VStack(spacing: 10) {
                HStack(spacing: 12) {
                    Button {
                        router.push(.player(
                            bookID: playback.bookID,
                            chapterID: playback.chapterID
                        ))
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

                    Button {
                        viewModel.togglePlayback(bookID: playback.bookID, chapterID: playback.chapterID)
                    } label: {
                        Image(systemName: viewModel.isActive(bookID: playback.bookID, chapterID: playback.chapterID)
                              && viewModel.isPlaying && !viewModel.isPaused ? "pause.fill" : "play.fill")
                            .frame(width: 36, height: 36)
                    }
                    .buttonStyle(.glass)
                }
            }
            .padding(10)
            .cardStyle(.Glass.beige, cornerRadius: 0)
            .padding(.bottom, 10)
        }
    }
}
