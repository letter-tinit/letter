import Domain
import Foundation

private enum OfflinePCMStreamingError: Error {
    case emptyAudio
}

@MainActor
final class OfflinePCMStreamingSession {
    private let synthesizer: any LocalSpeechSynthesizing
    private let request: SpeechPlaybackRequest
    private let chunks: [SpeechTextChunker.Chunk]
    private let startingIndex: Int
    private let characterOffset: Int
    private let chunking: LocalSpeechChunkingOptions
    private let player: PCMStreamPlayer
    private var task: Task<Void, Never>?

    var onChunkPlayed: ((Int) -> Void)?
    var onDrained: (() -> Void)?
    var onFailure: (() -> Void)?

    init(
        synthesizer: any LocalSpeechSynthesizing,
        request: SpeechPlaybackRequest,
        chunks: [SpeechTextChunker.Chunk],
        startingAt startingIndex: Int,
        characterOffset: Int,
        chunking: LocalSpeechChunkingOptions
    ) {
        self.synthesizer = synthesizer
        self.request = request
        self.chunks = chunks
        self.startingIndex = startingIndex
        self.characterOffset = characterOffset
        self.chunking = chunking
        player = PCMStreamPlayer(
            minimumBufferedDurationBeforePlayback: Self.startupBufferDuration(
                for: request.rateMultiplier
            )
        )
    }

    func start() {
        guard task == nil else { return }
        task = Task { [weak self] in
            guard let self else { return }
            do {
                try await produceAudio()
                try Task.checkCancellation()
                task = nil
                player.finishScheduling { [weak self] in
                    self?.onDrained?()
                }
            } catch is CancellationError {
                task = nil
            } catch {
                task = nil
                player.stop()
                onFailure?()
            }
        }
    }

    func pause() {
        player.pause()
    }

    func resume() {
        player.resume()
    }

    func cancel() {
        task?.cancel()
        task = nil
        player.stop()
    }

    private func produceAudio() async throws {
        guard chunks.indices.contains(startingIndex) else { return }
        for index in startingIndex..<chunks.count {
            try Task.checkCancellation()
            let chunk = chunks[index]
            let text = synthesisText(for: chunk, at: index)
            let stream = synthesizer.synthesizePCMStream(
                LocalSpeechSynthesisRequest(
                    text: text,
                    languageCode: request.languageCode,
                    rateMultiplier: request.rateMultiplier
                )
            )
            var emittedAudio = false
            var lastFormat: SynthesizedSpeechPCMChunk?
            for try await audio in stream {
                try Task.checkCancellation()
                try player.schedule(audio)
                emittedAudio = true
                lastFormat = audio
                await player.waitForCapacity(
                    maximumBufferedDuration: Self.maximumBufferedDuration(
                        for: request.rateMultiplier
                    )
                )
            }
            guard emittedAudio, let lastFormat else {
                throw OfflinePCMStreamingError.emptyAudio
            }
            try scheduleBoundaryPause(after: chunk.text, format: lastFormat)
            try player.scheduleMarker { [weak self] in
                self?.onChunkPlayed?(index)
            }
        }
    }

    private func synthesisText(
        for chunk: SpeechTextChunker.Chunk,
        at index: Int
    ) -> String {
        guard index == startingIndex,
              characterOffset > chunk.utf16Offset else { return chunk.text }
        let source = chunk.text as NSString
        let localOffset = min(
            max(characterOffset - chunk.utf16Offset, 0),
            source.length
        )
        return source.substring(from: localOffset)
    }

    private func scheduleBoundaryPause(
        after text: String,
        format: SynthesizedSpeechPCMChunk
    ) throws {
        let duration = chunking.pauseAfterChunk(text)
        guard duration > 0 else { return }
        try player.schedule(
            SynthesizedSpeechPCMChunk(
                samples: [Float](
                    repeating: 0,
                    count: Int(Double(format.sampleRate) * duration)
                ),
                sampleRate: format.sampleRate,
                playbackRate: format.playbackRate
            )
        )
    }

    private static func startupBufferDuration(for rate: Double) -> TimeInterval {
        let safeRate = min(max(rate, 0.5), 3)
        guard safeRate > 1 else { return 0.3 }
        return min(0.75 + (safeRate - 1) * 1.25, 3)
    }

    private static func maximumBufferedDuration(for rate: Double) -> TimeInterval {
        max(8, min(max(rate, 0.5), 3) * 4)
    }
}
