import AVFoundation
import Foundation

enum PCMStreamPlayerError: Error {
    case invalidAudioFormat
    case inconsistentAudioFormat
}

@MainActor
final class PCMStreamPlayer {
    private struct CapacityWaiter {
        let maximumDuration: TimeInterval
        let continuation: CheckedContinuation<Void, Never>
    }

    private let engine = AVAudioEngine()
    private let playerNode = AVAudioPlayerNode()
    private let timePitch = AVAudioUnitTimePitch()
    private let minimumBufferedDurationBeforePlayback: TimeInterval
    private var format: AVAudioFormat?
    private var playbackRate: Float = 1
    private var generation = UUID()
    private var scheduledBufferCount = 0
    private var bufferedDuration: TimeInterval = 0
    private var capacityWaiters: [CapacityWaiter] = []
    private var drainAction: (() -> Void)?
    private var isPaused = false
    private var isBuffering = true
    private var hasFinishedScheduling = false

    init(minimumBufferedDurationBeforePlayback: TimeInterval) {
        self.minimumBufferedDurationBeforePlayback = max(
            minimumBufferedDurationBeforePlayback,
            0
        )
        engine.attach(playerNode)
        engine.attach(timePitch)
    }

    func schedule(
        _ chunk: SynthesizedSpeechPCMChunk,
        onPlayed: (() -> Void)? = nil
    ) throws {
        guard !chunk.samples.isEmpty,
              chunk.sampleRate > 0,
              chunk.playbackRate > 0 else {
            throw PCMStreamPlayerError.invalidAudioFormat
        }
        try prepareIfNeeded(for: chunk)
        guard let format,
              let buffer = AVAudioPCMBuffer(
                pcmFormat: format,
                frameCapacity: AVAudioFrameCount(chunk.samples.count)
              ),
              let destination = buffer.floatChannelData?[0] else {
            throw PCMStreamPlayerError.invalidAudioFormat
        }
        buffer.frameLength = AVAudioFrameCount(chunk.samples.count)
        chunk.samples.withUnsafeBufferPointer { source in
            guard let baseAddress = source.baseAddress else { return }
            destination.update(from: baseAddress, count: source.count)
        }

        let itemGeneration = generation
        let duration = Double(chunk.samples.count) /
            Double(chunk.sampleRate) /
            Double(chunk.playbackRate)
        scheduledBufferCount += 1
        bufferedDuration += duration
        playerNode.scheduleBuffer(
            buffer,
            completionCallbackType: .dataPlayedBack
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.didPlayBuffer(
                    generation: itemGeneration,
                    duration: duration,
                    action: onPlayed
                )
            }
        }
        startPlaybackIfReady()
    }

    func scheduleMarker(action: @escaping () -> Void) throws {
        guard let format else {
            action()
            return
        }
        try schedule(
            SynthesizedSpeechPCMChunk(
                samples: [0],
                sampleRate: Int(format.sampleRate),
                playbackRate: playbackRate
            ),
            onPlayed: action
        )
    }

    func waitForCapacity(
        maximumBufferedDuration: TimeInterval
    ) async {
        guard bufferedDuration > maximumBufferedDuration else { return }
        await withCheckedContinuation { continuation in
            capacityWaiters.append(
                CapacityWaiter(
                    maximumDuration: maximumBufferedDuration,
                    continuation: continuation
                )
            )
        }
    }

    func finishScheduling(onDrained: @escaping () -> Void) {
        hasFinishedScheduling = true
        if scheduledBufferCount == 0 {
            onDrained()
        } else {
            drainAction = onDrained
            startPlaybackIfReady(force: true)
        }
    }

    func pause() {
        guard !isPaused else { return }
        isPaused = true
        playerNode.pause()
    }

    func resume() {
        guard isPaused else { return }
        isPaused = false
        startPlaybackIfReady(force: hasFinishedScheduling)
    }

    func stop() {
        generation = UUID()
        playerNode.stop()
        engine.stop()
        engine.reset()
        format = nil
        scheduledBufferCount = 0
        bufferedDuration = 0
        drainAction = nil
        isPaused = false
        isBuffering = true
        hasFinishedScheduling = false
        let waiters = capacityWaiters
        capacityWaiters = []
        waiters.forEach { $0.continuation.resume() }
    }

    private func prepareIfNeeded(
        for chunk: SynthesizedSpeechPCMChunk
    ) throws {
        if let format {
            guard Int(format.sampleRate) == chunk.sampleRate,
                  playbackRate == chunk.playbackRate else {
                throw PCMStreamPlayerError.inconsistentAudioFormat
            }
            return
        }
        guard let format = AVAudioFormat(
            commonFormat: .pcmFormatFloat32,
            sampleRate: Double(chunk.sampleRate),
            channels: 1,
            interleaved: false
        ) else {
            throw PCMStreamPlayerError.invalidAudioFormat
        }
        self.format = format
        playbackRate = chunk.playbackRate
        timePitch.rate = chunk.playbackRate
        timePitch.overlap = chunk.playbackRate >= 1.5 ? 16 : 8
        engine.connect(playerNode, to: timePitch, format: format)
        engine.connect(timePitch, to: engine.mainMixerNode, format: format)
        engine.prepare()
        try engine.start()
    }

    private func didPlayBuffer(
        generation itemGeneration: UUID,
        duration: TimeInterval,
        action: (() -> Void)?
    ) {
        guard itemGeneration == generation else { return }
        scheduledBufferCount = max(0, scheduledBufferCount - 1)
        bufferedDuration = max(0, bufferedDuration - duration)
        action?()
        resumeCapacityWaiters()
        if scheduledBufferCount == 0 {
            if hasFinishedScheduling, let drainAction {
                self.drainAction = nil
                drainAction()
            } else {
                isBuffering = true
                playerNode.pause()
            }
        }
    }

    private func startPlaybackIfReady(force: Bool = false) {
        guard !isPaused, scheduledBufferCount > 0 else { return }
        guard isBuffering || !playerNode.isPlaying else { return }
        guard force || bufferedDuration >= minimumBufferedDurationBeforePlayback else {
            isBuffering = true
            return
        }
        isBuffering = false
        if !playerNode.isPlaying {
            playerNode.play()
        }
    }

    private func resumeCapacityWaiters() {
        var pending: [CapacityWaiter] = []
        for waiter in capacityWaiters {
            if bufferedDuration <= waiter.maximumDuration {
                waiter.continuation.resume()
            } else {
                pending.append(waiter)
            }
        }
        capacityWaiters = pending
    }
}
