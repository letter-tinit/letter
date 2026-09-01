import AVFoundation
import Foundation
import Utility

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
    private let minimumBufferedDurationAfterUnderrun: TimeInterval
    private var format: AVAudioFormat?
    private var playbackRate: Float = 1
    private var generation = UUID()
    private var scheduledBufferCount = 0
    private var bufferedDuration: TimeInterval = 0
    private var capacityWaiters: [CapacityWaiter] = []
    private var drainAction: (() -> Void)?
    private var isPaused = false
    private var isBuffering = true
    private var hasStartedPlayback = false
    private var hasFinishedScheduling = false

    init(
        minimumBufferedDurationBeforePlayback: TimeInterval,
        minimumBufferedDurationAfterUnderrun: TimeInterval
    ) {
        self.minimumBufferedDurationBeforePlayback = max(
            minimumBufferedDurationBeforePlayback,
            0
        )
        self.minimumBufferedDurationAfterUnderrun = max(
            minimumBufferedDurationAfterUnderrun,
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
        startPlaybackIfReady(force: true)
    }

    func stop() {
        generation = UUID()
        playerNode.stop()
        engine.stop()
        disconnectAudioGraph()
        engine.reset()
        format = nil
        scheduledBufferCount = 0
        bufferedDuration = 0
        drainAction = nil
        isPaused = false
        isBuffering = true
        hasStartedPlayback = false
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
        disconnectAudioGraph()
        if abs(chunk.playbackRate - 1) < 0.001 {
            engine.connect(playerNode, to: engine.mainMixerNode, format: format)
            logAudioGraph(playbackRate: chunk.playbackRate, overlap: nil)
        } else {
            let overlap = Self.timePitchOverlap(for: chunk.playbackRate)
            timePitch.rate = chunk.playbackRate
            timePitch.overlap = overlap
            engine.connect(playerNode, to: timePitch, format: format)
            engine.connect(timePitch, to: engine.mainMixerNode, format: format)
            logAudioGraph(
                playbackRate: chunk.playbackRate,
                overlap: overlap
            )
        }
        engine.prepare()
        try engine.start()
    }

    private func disconnectAudioGraph() {
        engine.disconnectNodeOutput(playerNode)
        engine.disconnectNodeOutput(timePitch)
    }

    private func logAudioGraph(playbackRate: Float, overlap: Float?) {
#if DEBUG
        if let overlap {
            logDebug(
                "[Letter][Speech][PCM] " +
                String(
                    format: "rate=%.2f dsp=timePitch overlap=%.0f",
                    playbackRate,
                    overlap
                )
            )
        } else {
            logDebug(
                "[Letter][Speech][PCM] " +
                String(format: "rate=%.2f dsp=bypass", playbackRate)
            )
        }
#endif
    }

    private static func timePitchOverlap(for rate: Float) -> Float {
        if rate >= 2.25 { return 3 }
        if rate >= 1.75 { return 4 }
        if rate >= 1.25 { return 6 }
        return 8
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
        let requiredDuration = hasStartedPlayback
            ? minimumBufferedDurationAfterUnderrun
            : minimumBufferedDurationBeforePlayback
        guard force || bufferedDuration >= requiredDuration else {
            isBuffering = true
            return
        }
        isBuffering = false
        hasStartedPlayback = true
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
