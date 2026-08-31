import Foundation
import Domain

@MainActor
public final class SpeechPlaybackEngineRouter: SpeechPlaybackRepository {
    private let settings: any SpeechProviderSettingsRepository
    private let appleEngine: any SpeechPlaybackRepository
    private let googleEngine: any SpeechPlaybackRepository
    private var activeEngine: any SpeechPlaybackRepository
    private var activeRequest: SpeechPlaybackRequest?
    private var latestCharacterOffset = 0

    public var onProgress: ((SpeechPlaybackProgress) -> Void)?
    public var onFinished: (() -> Void)?
    public var onStateChanged: ((SpeechPlaybackState) -> Void)?
    public var onPreviousChapterRequested: (() -> Void)?
    public var onNextChapterRequested: (() -> Void)?
    public var onFailure: ((SpeechPlaybackFailure) -> Void)?

    public init(
        settings: any SpeechProviderSettingsRepository,
        appleEngine: any SpeechPlaybackRepository,
        googleEngine: any SpeechPlaybackRepository
    ) {
        self.settings = settings
        self.appleEngine = appleEngine
        self.googleEngine = googleEngine
        activeEngine = appleEngine
        bindCallbacks(to: appleEngine)
    }

    public func play(_ request: SpeechPlaybackRequest) {
        activeRequest = request
        latestCharacterOffset = request.characterOffset
        let engine = settings.loadProvider() == .googleCloud ? googleEngine : appleEngine
        activate(engine)
        engine.play(request)
    }

    public func pause() { activeEngine.pause() }
    public func resume() { activeEngine.resume() }
    public func stop() {
        activeEngine.stop()
        activeRequest = nil
        latestCharacterOffset = 0
    }

    public func skip(seconds: TimeInterval) {
        activeEngine.skip(seconds: seconds)
    }

    public func setChapterNavigation(previousEnabled: Bool, nextEnabled: Bool) {
        appleEngine.setChapterNavigation(previousEnabled: previousEnabled, nextEnabled: nextEnabled)
        googleEngine.setChapterNavigation(previousEnabled: previousEnabled, nextEnabled: nextEnabled)
    }

    private func activate(_ engine: any SpeechPlaybackRepository) {
        guard ObjectIdentifier(activeEngine) != ObjectIdentifier(engine) else { return }
        clearCallbacks(on: activeEngine)
        activeEngine.stop()
        activeEngine = engine
        bindCallbacks(to: engine)
    }

    private func bindCallbacks(to engine: any SpeechPlaybackRepository) {
        let isGoogleEngine = ObjectIdentifier(engine) == ObjectIdentifier(googleEngine)
        engine.onProgress = { [weak self] progress in
            self?.latestCharacterOffset = progress.characterOffset
            self?.onProgress?(progress)
        }
        engine.onFinished = { [weak self] in self?.onFinished?() }
        engine.onStateChanged = { [weak self] in self?.onStateChanged?($0) }
        engine.onPreviousChapterRequested = { [weak self] in self?.onPreviousChapterRequested?() }
        engine.onNextChapterRequested = { [weak self] in self?.onNextChapterRequested?() }
        engine.onFailure = { [weak self] failure in
            guard let self else { return }
            guard isGoogleEngine, let request = self.activeRequest else {
                self.onFailure?(failure)
                return
            }
            self.onFailure?(failure)
            self.activate(self.appleEngine)
            self.appleEngine.play(request.withOffset(self.latestCharacterOffset))
        }
    }

    private func clearCallbacks(on engine: any SpeechPlaybackRepository) {
        engine.onProgress = nil
        engine.onFinished = nil
        engine.onStateChanged = nil
        engine.onPreviousChapterRequested = nil
        engine.onNextChapterRequested = nil
        engine.onFailure = nil
    }
}
