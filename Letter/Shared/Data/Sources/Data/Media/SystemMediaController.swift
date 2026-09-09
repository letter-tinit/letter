import Foundation
import MediaPlayer
import Domain
import Utility

@MainActor
public final class SystemMediaController {
    public var onPlay: (() -> Void)?
    public var onPause: (() -> Void)?
    public var onToggle: (() -> Void)?
    public var onPreviousChapter: (() -> Void)?
    public var onNextChapter: (() -> Void)?
    public var onSkip: ((TimeInterval) -> Void)?
    public var onSeekToTime: ((TimeInterval) -> Void)?
    // MPRemoteCommandCenter is process-global. Keep one set of handlers and
    // route every command to the controller that most recently published
    // active Now Playing state. Each speech engine still owns its controller,
    // but inactive engines can no longer consume remote commands.
    private static weak var activeController: SystemMediaController?
    private static var commandTokens: [Any] = []
    private static var commandsConfigured = false

    public init() {
        Self.configureCommandsIfNeeded()
    }

    public func update(request: SpeechPlaybackRequest, characterOffset: Int, isPaused: Bool) {
        Self.activeController = self
        let duration = playbackDuration(for: request)
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
            MPNowPlayingInfoPropertyPlaybackRate: isPaused ? 0 : 1,
            MPNowPlayingInfoPropertyDefaultPlaybackRate: 1,
            MPNowPlayingInfoPropertyMediaType: MPNowPlayingInfoMediaType.audio.rawValue,
            MPNowPlayingInfoPropertyIsLiveStream: false,
            MPNowPlayingInfoPropertyExternalContentIdentifier: request.chapterID.uuidString,
            MPNowPlayingInfoPropertyServiceIdentifier: "Letter.AudioBook"
        ]
        infoCenter.playbackState = isPaused ? .paused : .playing
    }

    public func clear() {
        guard Self.activeController === self else { return }
        Self.activeController = nil
        let infoCenter = MPNowPlayingInfoCenter.default()
        infoCenter.playbackState = .stopped
        infoCenter.nowPlayingInfo = nil
    }

    public func setChapterNavigation(previousEnabled: Bool, nextEnabled: Bool) {
        let commands = MPRemoteCommandCenter.shared()
        commands.previousTrackCommand.isEnabled = previousEnabled
        commands.nextTrackCommand.isEnabled = nextEnabled
    }

    public func playbackDuration(for request: SpeechPlaybackRequest) -> TimeInterval {
        let baseDuration = Double(request.text.utf16.count) / 14
        return baseDuration / max(request.rateMultiplier, 0.1)
    }

    private static func configureCommandsIfNeeded() {
        guard !commandsConfigured else { return }
        commandsConfigured = true
        let commands = MPRemoteCommandCenter.shared()
        commands.playCommand.isEnabled = true
        commands.pauseCommand.isEnabled = true
        commands.togglePlayPauseCommand.isEnabled = true
        commands.skipBackwardCommand.isEnabled = true
        commands.skipForwardCommand.isEnabled = true
        commands.previousTrackCommand.isEnabled = false
        commands.nextTrackCommand.isEnabled = false
        commands.changePlaybackPositionCommand.isEnabled = true
        commands.skipBackwardCommand.preferredIntervals = [15]
        commands.skipForwardCommand.preferredIntervals = [15]

        commandTokens.append(commands.playCommand.addTarget { _ in
            Task { @MainActor in Self.activeController?.onPlay?() }
            return .success
        })
        commandTokens.append(commands.pauseCommand.addTarget { _ in
            Task { @MainActor in Self.activeController?.onPause?() }
            return .success
        })
        commandTokens.append(commands.togglePlayPauseCommand.addTarget { _ in
            Task { @MainActor in Self.activeController?.onToggle?() }
            return .success
        })
        commandTokens.append(commands.previousTrackCommand.addTarget { _ in
            Task { @MainActor in Self.activeController?.onPreviousChapter?() }
            return .success
        })
        commandTokens.append(commands.nextTrackCommand.addTarget { _ in
            Task { @MainActor in Self.activeController?.onNextChapter?() }
            return .success
        })
        commandTokens.append(commands.skipBackwardCommand.addTarget { event in
            let seconds = (event as? MPSkipIntervalCommandEvent)?.interval ?? 15
            Task { @MainActor in Self.activeController?.onSkip?(-seconds) }
            return .success
        })
        commandTokens.append(commands.skipForwardCommand.addTarget { event in
            let seconds = (event as? MPSkipIntervalCommandEvent)?.interval ?? 15
            Task { @MainActor in Self.activeController?.onSkip?(seconds) }
            return .success
        })
        commandTokens.append(commands.changePlaybackPositionCommand.addTarget { event in
            guard let positionEvent = event as? MPChangePlaybackPositionCommandEvent else {
                return .commandFailed
            }
            Task { @MainActor in Self.activeController?.onSeekToTime?(positionEvent.positionTime) }
            return .success
        })
    }
}
