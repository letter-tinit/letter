import Foundation
import MediaPlayer

@MainActor
final class SystemMediaController {
    var onPlay: (() -> Void)?
    var onPause: (() -> Void)?
    var onToggle: (() -> Void)?
    var onSkip: ((TimeInterval) -> Void)?
    var onSeekToTime: ((TimeInterval) -> Void)?
    private var commandTokens: [Any] = []

    init() {
        configureCommands()
    }

    func update(request: SpeechPlaybackRequest, characterOffset: Int, isPaused: Bool) {
        let duration = estimatedDuration(for: request)
        let fraction = request.text.utf16.isEmpty
            ? 0
            : Double(characterOffset) / Double(request.text.utf16.count)
        let infoCenter = MPNowPlayingInfoCenter.default()
        infoCenter.nowPlayingInfo = [
            MPMediaItemPropertyTitle: request.chapterTitle,
            MPMediaItemPropertyAlbumTitle: request.bookTitle,
            MPMediaItemPropertyArtist: request.bookTitle,
            MPMediaItemPropertyPlaybackDuration: duration,
            MPNowPlayingInfoPropertyElapsedPlaybackTime: duration * fraction,
            MPNowPlayingInfoPropertyPlaybackRate: isPaused ? 0 : request.rateMultiplier,
            MPNowPlayingInfoPropertyDefaultPlaybackRate: request.rateMultiplier,
            MPNowPlayingInfoPropertyMediaType: MPNowPlayingInfoMediaType.audio.rawValue,
            MPNowPlayingInfoPropertyIsLiveStream: false,
            MPNowPlayingInfoPropertyExternalContentIdentifier: request.chapterID.uuidString,
            MPNowPlayingInfoPropertyServiceIdentifier: "Letter.AudioBook"
        ]
        infoCenter.playbackState = isPaused ? .paused : .playing
    }

    func clear() {
        let infoCenter = MPNowPlayingInfoCenter.default()
        infoCenter.playbackState = .stopped
        infoCenter.nowPlayingInfo = nil
    }

    private func configureCommands() {
        let commands = MPRemoteCommandCenter.shared()
        commands.playCommand.isEnabled = true
        commands.pauseCommand.isEnabled = true
        commands.togglePlayPauseCommand.isEnabled = true
        commands.skipBackwardCommand.isEnabled = true
        commands.skipForwardCommand.isEnabled = true
        commands.changePlaybackPositionCommand.isEnabled = true
        commands.skipBackwardCommand.preferredIntervals = [15]
        commands.skipForwardCommand.preferredIntervals = [15]

        commandTokens.append(commands.playCommand.addTarget { [weak self] _ in
            Task { @MainActor in self?.onPlay?() }
            return .success
        })
        commandTokens.append(commands.pauseCommand.addTarget { [weak self] _ in
            Task { @MainActor in self?.onPause?() }
            return .success
        })
        commandTokens.append(commands.togglePlayPauseCommand.addTarget { [weak self] _ in
            Task { @MainActor in self?.onToggle?() }
            return .success
        })
        commandTokens.append(commands.skipBackwardCommand.addTarget { [weak self] event in
            let seconds = (event as? MPSkipIntervalCommandEvent)?.interval ?? 15
            Task { @MainActor in self?.onSkip?(-seconds) }
            return .success
        })
        commandTokens.append(commands.skipForwardCommand.addTarget { [weak self] event in
            let seconds = (event as? MPSkipIntervalCommandEvent)?.interval ?? 15
            Task { @MainActor in self?.onSkip?(seconds) }
            return .success
        })
        commandTokens.append(commands.changePlaybackPositionCommand.addTarget { [weak self] event in
            guard let positionEvent = event as? MPChangePlaybackPositionCommandEvent else {
                return .commandFailed
            }
            Task { @MainActor in self?.onSeekToTime?(positionEvent.positionTime) }
            return .success
        })
    }

    private func estimatedDuration(for request: SpeechPlaybackRequest) -> TimeInterval {
        Double(request.text.utf16.count) / 14
    }
}
