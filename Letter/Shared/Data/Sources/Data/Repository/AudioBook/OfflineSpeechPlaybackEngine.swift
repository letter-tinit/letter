import AVFoundation
import Foundation
import Domain

@MainActor
public final class OfflineSpeechPlaybackEngine: NSObject, SpeechPlaybackRepository, AVAudioPlayerDelegate {
    private let synthesizer: any OfflineSpeechSynthesizing
    private let mediaController = SystemMediaController()
    private var request: SpeechPlaybackRequest?
    private var chunks: [SpeechTextChunker.Chunk] = []
    private var chunkIndex = 0
    private var currentOffset = 0
    private var pendingChunkFraction: Double?
    private var generation = UUID()
    private var synthesisTask: Task<Void, Never>?
    private var audioTasks: [Int: Task<OfflineSynthesizedAudio, Error>] = [:]
    private var progressTimer: Timer?
    private var player: AVAudioPlayer?
    private var isPaused = false

    public var onProgress: ((SpeechPlaybackProgress) -> Void)?
    public var onFinished: (() -> Void)?
    public var onStateChanged: ((SpeechPlaybackState) -> Void)?
    public var onPreviousChapterRequested: (() -> Void)?
    public var onNextChapterRequested: (() -> Void)?
    public var onFailure: ((SpeechPlaybackFailure) -> Void)?

    init(synthesizer: any OfflineSpeechSynthesizing) {
        self.synthesizer = synthesizer
        super.init()
        bindMediaControls()
    }

    public convenience init(models: BundledOfflineSpeechModels) {
        self.init(synthesizer: SherpaOnnxSpeechSynthesizer(paths: models.paths))
    }

    public func play(_ request: SpeechPlaybackRequest) {
        stop()
        configureAudioSession()
        self.request = request
        currentOffset = request.characterOffset
        chunks = SpeechTextChunker().chunks(text: request.text, startingAt: 0, maximumLength: 600)
        selectChunk(containing: request.characterOffset)
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
        stopProgressTimer()
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
        audioTasks = [:]
        stopProgressTimer()
        player?.stop()
        player = nil
        request = nil
        chunks = []
        currentOffset = 0
        pendingChunkFraction = nil
        isPaused = false
        mediaController.clear()
        onStateChanged?(.stopped)
    }

    public func skip(seconds: TimeInterval) {
        guard let request else { return }
        if seekInsideCurrentAudio(seconds: seconds) { return }
        let delta = Int(seconds * 14 * request.rateMultiplier)
        play(request.withOffset(min(max(currentOffset + delta, 0), request.text.utf16.count)))
    }

    public func setChapterNavigation(previousEnabled: Bool, nextEnabled: Bool) {
        mediaController.setChapterNavigation(
            previousEnabled: previousEnabled,
            nextEnabled: nextEnabled
        )
    }

    public nonisolated func audioPlayerDidFinishPlaying(
        _ player: AVAudioPlayer,
        successfully flag: Bool
    ) {
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
                self?.startPlayback(audio.waveData, generation: generation)
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
    ) -> Task<OfflineSynthesizedAudio, Error> {
        if let task = audioTasks[index] { return task }
        let chunk = chunks[index]
        let task = Task { [synthesizer] in
            try await synthesizer.synthesize(
                text: chunk.text,
                languageCode: request.languageCode,
                rate: request.rateMultiplier
            )
        }
        audioTasks[index] = task
        return task
    }

    private func startPlayback(_ audio: Data, generation: UUID) {
        guard generation == self.generation else { return }
        synthesisTask = nil
        do {
            let player = try AVAudioPlayer(data: audio)
            player.delegate = self
            player.prepareToPlay()
            if let pendingChunkFraction {
                player.currentTime = player.duration * pendingChunkFraction
                self.pendingChunkFraction = nil
            }
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
        onFailure?(.offlineUnavailable)
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
        guard let player, player.duration > 0, chunks.indices.contains(chunkIndex) else { return }
        let chunk = chunks[chunkIndex]
        let fraction = min(max(player.currentTime / player.duration, 0), 1)
        currentOffset = chunk.utf16Offset + Int(Double(chunk.utf16Length) * fraction)
        updateSystemMediaState()
        reportProgress()
    }

    private func stopProgressTimer() {
        progressTimer?.invalidate()
        progressTimer = nil
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

    private func seekInsideCurrentAudio(seconds: TimeInterval) -> Bool {
        guard let player else { return false }
        let target = player.currentTime + seconds
        guard target >= 0, target <= player.duration else { return false }
        player.currentTime = target
        progressTimerDidFire()
        return true
    }

    private func selectChunk(containing offset: Int) {
        guard let index = chunks.firstIndex(where: {
            offset < $0.utf16Offset + $0.utf16Length
        }) else {
            chunkIndex = chunks.count
            pendingChunkFraction = nil
            return
        }
        chunkIndex = index
        let chunk = chunks[index]
        pendingChunkFraction = min(
            max(Double(offset - chunk.utf16Offset) / Double(chunk.utf16Length), 0),
            1
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
            isPaused ? resume() : pause()
        }
        mediaController.onPreviousChapter = { [weak self] in self?.onPreviousChapterRequested?() }
        mediaController.onNextChapter = { [weak self] in self?.onNextChapterRequested?() }
        mediaController.onSkip = { [weak self] in self?.skip(seconds: $0) }
        mediaController.onSeekToTime = { [weak self] time in
            guard let self, let request else { return }
            let duration = Double(request.text.utf16.count) / (14 * request.rateMultiplier)
            guard duration > 0 else { return }
            let fraction = min(max(time / duration, 0), 1)
            play(request.withOffset(Int(Double(request.text.utf16.count) * fraction)))
        }
    }

    private func updateSystemMediaState() {
        guard let request else { return }
        mediaController.update(request: request, characterOffset: currentOffset, isPaused: isPaused)
    }
}
