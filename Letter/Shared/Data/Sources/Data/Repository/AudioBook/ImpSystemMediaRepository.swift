import Foundation
import MediaPlayer
import Domain

@MainActor
public final class ImpSystemMediaRepository: SystemMediaRepository {
    public var onPlay: (() -> Void)?
    public var onPause: (() -> Void)?
    public var onToggle: (() -> Void)?
    public var onPreviousChapter: (() -> Void)?
    public var onNextChapter: (() -> Void)?
    public var onSkip: ((TimeInterval) -> Void)?
    public var onSeekToTime: ((TimeInterval) -> Void)?
    // iOS command registration is process-global, including across app previews.
    // The most recently publishing repository owns the system media session.
    private var previousChapterEnabled = false
    private var nextChapterEnabled = false
    private static weak var activeRepository: ImpSystemMediaRepository?
    private static var commandTokens: [Any] = []
    private static var commandsConfigured = false

    public init() {
        Self.configureCommandsIfNeeded()
    }

    public func update(_ state: SystemMediaState) {
        Self.activeRepository = self
        updateChapterNavigation()
        let infoCenter = MPNowPlayingInfoCenter.default()
        infoCenter.nowPlayingInfo = [
            MPMediaItemPropertyTitle: state.title,
            MPMediaItemPropertyAlbumTitle: state.bookTitle,
            MPMediaItemPropertyArtist: state.bookTitle,
            MPMediaItemPropertyPlaybackDuration: state.duration,
            MPNowPlayingInfoPropertyElapsedPlaybackTime: state.elapsedTime,
            MPNowPlayingInfoPropertyPlaybackRate: state.playbackState == .playing ? 1 : 0,
            MPNowPlayingInfoPropertyDefaultPlaybackRate: 1,
            MPNowPlayingInfoPropertyMediaType: MPNowPlayingInfoMediaType.audio.rawValue,
            MPNowPlayingInfoPropertyIsLiveStream: false,
            MPNowPlayingInfoPropertyExternalContentIdentifier: state.identifier,
            MPNowPlayingInfoPropertyServiceIdentifier: "Letter.AudioBook"
        ]
        switch state.playbackState {
        case .playing: infoCenter.playbackState = .playing
        case .paused: infoCenter.playbackState = .paused
        case .stopped: infoCenter.playbackState = .stopped
        }
    }

    public func clear() {
        guard Self.activeRepository === self else { return }
        Self.activeRepository = nil
        let infoCenter = MPNowPlayingInfoCenter.default()
        infoCenter.playbackState = .stopped
        infoCenter.nowPlayingInfo = nil
    }

    public func setChapterNavigation(previousEnabled: Bool, nextEnabled: Bool) {
        previousChapterEnabled = previousEnabled
        nextChapterEnabled = nextEnabled
        guard Self.activeRepository === self else { return }
        updateChapterNavigation()
    }

    private func updateChapterNavigation() {
        let commands = MPRemoteCommandCenter.shared()
        commands.previousTrackCommand.isEnabled = previousChapterEnabled
        commands.nextTrackCommand.isEnabled = nextChapterEnabled
    }

    private static func configureCommandsIfNeeded() {
        guard !commandsConfigured else { return }
        commandsConfigured = true
        let commands = MPRemoteCommandCenter.shared()
        enableCommands(commands)
        bindTransportCommands(commands)
        bindChapterCommands(commands)
        bindSeekCommands(commands)
    }

    private static func enableCommands(_ commands: MPRemoteCommandCenter) {
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
    }

    private static func bindTransportCommands(_ commands: MPRemoteCommandCenter) {
        commandTokens.append(commands.playCommand.addTarget { _ in
            Task { @MainActor in Self.activeRepository?.onPlay?() }
            return .success
        })
        commandTokens.append(commands.pauseCommand.addTarget { _ in
            Task { @MainActor in Self.activeRepository?.onPause?() }
            return .success
        })
        commandTokens.append(commands.togglePlayPauseCommand.addTarget { _ in
            Task { @MainActor in Self.activeRepository?.onToggle?() }
            return .success
        })
    }

    private static func bindChapterCommands(_ commands: MPRemoteCommandCenter) {
        commandTokens.append(commands.previousTrackCommand.addTarget { _ in
            Task { @MainActor in Self.activeRepository?.onPreviousChapter?() }
            return .success
        })
        commandTokens.append(commands.nextTrackCommand.addTarget { _ in
            Task { @MainActor in Self.activeRepository?.onNextChapter?() }
            return .success
        })
    }

    private static func bindSeekCommands(_ commands: MPRemoteCommandCenter) {
        commandTokens.append(commands.skipBackwardCommand.addTarget { event in
            let seconds = (event as? MPSkipIntervalCommandEvent)?.interval ?? 15
            Task { @MainActor in Self.activeRepository?.onSkip?(-seconds) }
            return .success
        })
        commandTokens.append(commands.skipForwardCommand.addTarget { event in
            let seconds = (event as? MPSkipIntervalCommandEvent)?.interval ?? 15
            Task { @MainActor in Self.activeRepository?.onSkip?(seconds) }
            return .success
        })
        commandTokens.append(commands.changePlaybackPositionCommand.addTarget { event in
            guard let positionEvent = event as? MPChangePlaybackPositionCommandEvent else {
                return .commandFailed
            }
            Task { @MainActor in Self.activeRepository?.onSeekToTime?(positionEvent.positionTime) }
            return .success
        })
    }
}
