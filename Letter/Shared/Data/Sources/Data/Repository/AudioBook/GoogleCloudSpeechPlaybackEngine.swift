import AVFoundation
import Foundation
import Domain

@MainActor
public final class GoogleCloudSpeechPlaybackEngine: NSObject, SpeechPlaybackRepository, AVAudioPlayerDelegate {
    private let client: any GoogleCloudSpeechSynthesizing
    private let mediaController = SystemMediaController()
    private var request: SpeechPlaybackRequest?
    private var chunks: [SpeechTextChunker.Chunk] = []
    private var chunkIndex = 0
    private var currentOffset = 0
    private var generation = UUID()
    private var synthesisTask: Task<Void, Never>?
    private var audioTasks: [Int: Task<Data, Error>] = [:]
    private var progressTimer: Timer?
    private var player: AVAudioPlayer?
    private var isPaused = false

    public var onProgress: ((SpeechPlaybackProgress) -> Void)?
    public var onFinished: (() -> Void)?
    public var onStateChanged: ((SpeechPlaybackState) -> Void)?
    public var onPreviousChapterRequested: (() -> Void)?
    public var onNextChapterRequested: (() -> Void)?
    public var onFailure: ((SpeechPlaybackFailure) -> Void)?

    public init(client: any GoogleCloudSpeechSynthesizing) {
        self.client = client
        super.init()
        bindMediaControls()
    }

    public func play(_ request: SpeechPlaybackRequest) {
        stop()
        configureAudioSession()
        self.request = request
        currentOffset = request.characterOffset
        chunks = SpeechTextChunker().chunks(
            text: request.text,
            startingAt: request.characterOffset,
            maximumLength: 1_200
        )
        chunkIndex = 0
        isPaused = false
        generation = UUID()
        updateSystemMediaState()
        onStateChanged?(.playing)
        synthesizeCurrentChunk(generation: generation)
    }

    public func pause() {
        guard request != nil, !isPaused else { return }
        player?.pause()
        isPaused = true
        updateSystemMediaState()
        onStateChanged?(.paused)
    }

    public func resume() {
        guard let request else { return }
        if currentOffset >= request.text.utf16.count {
            play(request.withOffset(0))
            return
        }
        isPaused = false
        if let player {
            player.play()
            startProgressTimer()
        } else if synthesisTask == nil {
            synthesizeCurrentChunk(generation: generation)
        }
        updateSystemMediaState()
        onStateChanged?(.playing)
    }

    public func stop() {
        generation = UUID()
        synthesisTask?.cancel()
        synthesisTask = nil
        audioTasks.values.forEach { $0.cancel() }
        audioTasks.removeAll()
        stopProgressTimer()
        player?.stop()
        player = nil
        request = nil
        chunks = []
        currentOffset = 0
        isPaused = false
        mediaController.clear()
        onStateChanged?(.stopped)
    }

    public func setChapterNavigation(previousEnabled: Bool, nextEnabled: Bool) {
        mediaController.setChapterNavigation(
            previousEnabled: previousEnabled,
            nextEnabled: nextEnabled
        )
    }

    public nonisolated func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        Task { @MainActor [weak self] in self?.finishCurrentChunk(successfully: flag) }
    }

    private func synthesizeCurrentChunk(generation: UUID) {
        guard chunks.indices.contains(chunkIndex), let request else {
            finishChapter()
            return
        }
        let index = chunkIndex
        let task = audioTask(index: index, request: request)
        synthesisTask = Task { [weak self] in
            do {
                let audio = try await task.value
                try Task.checkCancellation()
                self?.audioTasks[index] = nil
                self?.startPlayback(audio: audio, generation: generation)
            } catch is CancellationError {
                return
            } catch {
                self?.failPlayback(generation: generation)
            }
        }
    }

    private func audioTask(
        index: Int,
        request: SpeechPlaybackRequest
    ) -> Task<Data, Error> {
        if let task = audioTasks[index] { return task }
        let chunk = chunks[index]
        let task = Task { [client] in
            try await client.synthesize(
                GoogleCloudSpeechRequest(
                    text: chunk.text,
                    languageCode: request.languageCode,
                    rate: request.rateMultiplier
                )
            )
        }
        audioTasks[index] = task
        return task
    }

    private func startPlayback(audio: Data, generation: UUID) {
        guard generation == self.generation else { return }
        synthesisTask = nil
        do {
            let player = try AVAudioPlayer(data: audio)
            player.delegate = self
            player.enableRate = true
            player.rate = localPlaybackRate
            player.prepareToPlay()
            self.player = player
            if !isPaused {
                player.play()
                startProgressTimer()
            }
            prefetchNextChunk()
        } catch {
            failPlayback(generation: generation)
        }
    }

    private func prefetchNextChunk() {
        guard let request else { return }
        let nextIndex = chunkIndex + 1
        guard chunks.indices.contains(nextIndex) else { return }
        _ = audioTask(index: nextIndex, request: request)
    }

    private var localPlaybackRate: Float {
        guard let request, request.rateMultiplier > 2 else { return 1 }
        return Float(min(request.rateMultiplier / 2, 2))
    }

    private func finishCurrentChunk(successfully: Bool) {
        guard successfully, chunks.indices.contains(chunkIndex) else {
            failPlayback(generation: generation)
            return
        }
        stopProgressTimer()
        currentOffset = chunks[chunkIndex].utf16Offset + chunks[chunkIndex].utf16Length
        reportProgress()
        player = nil
        chunkIndex += 1
        synthesizeCurrentChunk(generation: generation)
    }

    private func finishChapter() {
        guard let request else { return }
        currentOffset = request.text.utf16.count
        isPaused = true
        updateSystemMediaState()
        reportProgress()
        onStateChanged?(.stopped)
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
        onFinished?()
    }

    private func failPlayback(generation: UUID) {
        guard generation == self.generation else { return }
        synthesisTask = nil
        stopProgressTimer()
        player = nil
        isPaused = true
        updateSystemMediaState()
        onStateChanged?(.stopped)
        onFailure?(.unavailable)
    }

    private func startProgressTimer() {
        stopProgressTimer()
        progressTimer = Timer.scheduledTimer(
            timeInterval: 0.25,
            target: self,
            selector: #selector(progressTimerDidFire),
            userInfo: nil,
            repeats: true
        )
    }

    @objc private func progressTimerDidFire() {
        updateTimedProgress()
    }

    private func stopProgressTimer() {
        progressTimer?.invalidate()
        progressTimer = nil
    }

    private func updateTimedProgress() {
        guard let player, player.duration > 0, chunks.indices.contains(chunkIndex) else { return }
        let chunk = chunks[chunkIndex]
        let fraction = min(max(player.currentTime / player.duration, 0), 1)
        currentOffset = chunk.utf16Offset + Int(Double(chunk.utf16Length) * fraction)
        updateSystemMediaState()
        reportProgress()
    }

    private func reportProgress() {
        guard let request else { return }
        onProgress?(
            SpeechPlaybackProgress(
                chapterID: request.chapterID,
                characterOffset: currentOffset,
                totalCharacterCount: request.text.utf16.count
            )
        )
    }

    private func configureAudioSession() {
        let session = AVAudioSession.sharedInstance()
        try? session.setCategory(.playback, mode: .spokenAudio, policy: .longFormAudio)
        try? session.setActive(true)
    }

    private func bindMediaControls() {
        mediaController.onPlay = { [weak self] in self?.resume() }
        mediaController.onPause = { [weak self] in self?.pause() }
        mediaController.onToggle = { [weak self] in
            guard let self else { return }
            self.isPaused ? self.resume() : self.pause()
        }
        mediaController.onPreviousChapter = { [weak self] in self?.onPreviousChapterRequested?() }
        mediaController.onNextChapter = { [weak self] in self?.onNextChapterRequested?() }
        mediaController.onSkip = { [weak self] seconds in self?.seek(seconds: seconds) }
        mediaController.onSeekToTime = { [weak self] time in self?.seek(toPlaybackTime: time) }
    }

    private func seek(seconds: TimeInterval) {
        guard let request else { return }
        let delta = Int(seconds * 14 * request.rateMultiplier)
        let target = min(max(currentOffset + delta, 0), request.text.utf16.count)
        play(request.withOffset(target))
    }

    private func seek(toPlaybackTime time: TimeInterval) {
        guard let request else { return }
        let duration = Double(request.text.utf16.count) / (14 * request.rateMultiplier)
        guard duration > 0 else { return }
        let target = Int(Double(request.text.utf16.count) * min(max(time / duration, 0), 1))
        play(request.withOffset(target))
    }

    private func updateSystemMediaState() {
        guard let request else { return }
        mediaController.update(request: request, characterOffset: currentOffset, isPaused: isPaused)
    }
}
