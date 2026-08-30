import AVFoundation
import Foundation

@MainActor
final class AppleSpeechPlaybackEngine: NSObject, SpeechPlaybackEngine, AVSpeechSynthesizerDelegate {
    private struct UtteranceContext {
        let generation: UUID
        let chapterID: UUID
        let baseOffset: Int
        let totalCharacterCount: Int
    }

    private let synthesizer = AVSpeechSynthesizer()
    private let mediaController = SystemMediaController()
    private var generation = UUID()
    private var contexts: [ObjectIdentifier: UtteranceContext] = [:]
    private var activeRequest: SpeechPlaybackRequest?
    private var currentOffset = 0
    private var isPaused = false
    var onProgress: ((SpeechPlaybackProgress) -> Void)?
    var onFinished: (() -> Void)?
    var onStateChanged: ((SpeechPlaybackState) -> Void)?

    override init() {
        super.init()
        synthesizer.delegate = self
        synthesizer.usesApplicationAudioSession = true
        bindMediaControls()
    }

    func availableVoices() -> [SpeechVoice] {
        AVSpeechSynthesisVoice.speechVoices()
            .filter { $0.language.hasPrefix("vi") }
            .map {
                SpeechVoice(
                    id: $0.identifier,
                    name: $0.name,
                    languageCode: $0.language,
                    quality: $0.quality.domainQuality
                )
            }
    }

    func play(_ request: SpeechPlaybackRequest) {
        stop()
        configureAudioSession()
        activeRequest = request
        currentOffset = request.characterOffset
        isPaused = false
        generation = UUID()
        let activeGeneration = generation
        let voice = request.voiceID.flatMap(AVSpeechSynthesisVoice.init(identifier:))
            ?? AVSpeechSynthesisVoice(language: "vi-VN")
        let chunks = SpeechTextChunker().chunks(
            text: request.text,
            startingAt: request.characterOffset,
            maximumLength: 2_000
        )

        for chunk in chunks {
            let utterance = AVSpeechUtterance(string: chunk.text)
            utterance.voice = voice
            utterance.rate = speechRate(multiplier: request.rateMultiplier)
            contexts[ObjectIdentifier(utterance)] = UtteranceContext(
                generation: activeGeneration,
                chapterID: request.chapterID,
                baseOffset: chunk.utf16Offset,
                totalCharacterCount: request.text.utf16.count
            )
            synthesizer.speak(utterance)
        }
        updateSystemMediaState()
        onStateChanged?(.playing)
    }

    func pause() {
        if synthesizer.pauseSpeaking(at: .word) {
            isPaused = true
            updateSystemMediaState()
            onStateChanged?(.paused)
        }
    }

    func resume() {
        if synthesizer.continueSpeaking() {
            isPaused = false
            updateSystemMediaState()
            onStateChanged?(.playing)
        } else if let activeRequest {
            play(activeRequest.withOffset(currentOffset))
        }
    }

    func stop() {
        generation = UUID()
        contexts.removeAll()
        synthesizer.stopSpeaking(at: .immediate)
        activeRequest = nil
        currentOffset = 0
        isPaused = false
        mediaController.clear()
        onStateChanged?(.stopped)
    }

    nonisolated func speechSynthesizer(
        _ synthesizer: AVSpeechSynthesizer,
        willSpeakRangeOfSpeechString characterRange: NSRange,
        utterance: AVSpeechUtterance
    ) {
        let utteranceID = ObjectIdentifier(utterance)
        Task { @MainActor [weak self] in
            guard let self,
                  let context = self.contexts[utteranceID],
                  context.generation == self.generation else { return }
            self.currentOffset = context.baseOffset + characterRange.location
            self.updateSystemMediaState()
            self.onProgress?(
                SpeechPlaybackProgress(
                    chapterID: context.chapterID,
                    characterOffset: self.currentOffset,
                    totalCharacterCount: context.totalCharacterCount
                )
            )
        }
    }

    nonisolated func speechSynthesizer(
        _ synthesizer: AVSpeechSynthesizer,
        didFinish utterance: AVSpeechUtterance
    ) {
        let utteranceID = ObjectIdentifier(utterance)
        Task { @MainActor [weak self] in
            guard let self,
                  let context = self.contexts.removeValue(forKey: utteranceID),
                  context.generation == self.generation else { return }
            let hasPendingUtterances = self.contexts.values.contains { $0.generation == context.generation }
            guard !hasPendingUtterances else { return }
            self.currentOffset = context.totalCharacterCount
            self.isPaused = true
            self.updateSystemMediaState()
            self.onProgress?(
                SpeechPlaybackProgress(
                    chapterID: context.chapterID,
                    characterOffset: context.totalCharacterCount,
                    totalCharacterCount: context.totalCharacterCount
                )
            )
            self.onFinished?()
            self.onStateChanged?(.stopped)
            try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
        }
    }

    nonisolated func speechSynthesizer(
        _ synthesizer: AVSpeechSynthesizer,
        didCancel utterance: AVSpeechUtterance
    ) {
        let utteranceID = ObjectIdentifier(utterance)
        Task { @MainActor [weak self] in
            self?.contexts.removeValue(forKey: utteranceID)
        }
    }

    private func speechRate(multiplier: Double) -> Float {
        let proposed: Float
        if multiplier <= 1 {
            proposed = AVSpeechUtteranceDefaultSpeechRate * Float(multiplier)
        } else {
            let normalized = Float((multiplier - 1) / 2)
            proposed = AVSpeechUtteranceDefaultSpeechRate
                + (AVSpeechUtteranceMaximumSpeechRate - AVSpeechUtteranceDefaultSpeechRate) * normalized
        }
        return min(max(proposed, AVSpeechUtteranceMinimumSpeechRate), AVSpeechUtteranceMaximumSpeechRate)
    }

    private func configureAudioSession() {
        let session = AVAudioSession.sharedInstance()
        try? session.setCategory(
            .playback,
            mode: .spokenAudio,
            policy: .longFormAudio,
            options: []
        )
        try? session.setActive(true)
    }

    private func bindMediaControls() {
        mediaController.onPlay = { [weak self] in self?.resume() }
        mediaController.onPause = { [weak self] in self?.pause() }
        mediaController.onToggle = { [weak self] in
            guard let self else { return }
            self.isPaused ? self.resume() : self.pause()
        }
        mediaController.onSkip = { [weak self] seconds in self?.seek(seconds: seconds) }
        mediaController.onSeekToTime = { [weak self] time in self?.seek(toPlaybackTime: time) }
    }

    private func seek(seconds: TimeInterval) {
        guard let activeRequest else { return }
        let charactersPerSecond = 14.0
        let delta = Int(seconds * charactersPerSecond)
        let target = min(max(currentOffset + delta, 0), activeRequest.text.utf16.count)
        play(activeRequest.withOffset(target))
    }

    private func seek(toPlaybackTime time: TimeInterval) {
        guard let activeRequest else { return }
        let duration = Double(activeRequest.text.utf16.count) / 14
        guard duration > 0 else { return }
        let fraction = min(max(time / duration, 0), 1)
        let target = Int(Double(activeRequest.text.utf16.count) * fraction)
        play(activeRequest.withOffset(target))
    }

    private func updateSystemMediaState() {
        guard let activeRequest else { return }
        mediaController.update(request: activeRequest, characterOffset: currentOffset, isPaused: isPaused)
    }
}

private extension SpeechPlaybackRequest {
    func withOffset(_ offset: Int) -> SpeechPlaybackRequest {
        SpeechPlaybackRequest(
            bookTitle: bookTitle,
            chapterTitle: chapterTitle,
            chapterID: chapterID,
            text: text,
            characterOffset: offset,
            rateMultiplier: rateMultiplier,
            voiceID: voiceID
        )
    }
}

private extension AVSpeechSynthesisVoiceQuality {
    var domainQuality: SpeechVoiceQuality {
        switch self {
        case .default: .standard
        case .enhanced: .enhanced
        case .premium: .premium
        @unknown default: .standard
        }
    }
}

private struct SpeechTextChunker {
    struct Chunk {
        let text: String
        let utf16Offset: Int
    }

    func chunks(text: String, startingAt offset: Int, maximumLength: Int) -> [Chunk] {
        let source = text as NSString
        var location = min(max(offset, 0), source.length)
        var result: [Chunk] = []
        while location < source.length {
            let remaining = source.length - location
            var length = min(maximumLength, remaining)
            if length < remaining {
                let candidate = source.substring(with: NSRange(location: location, length: length)) as NSString
                let boundary = candidate.rangeOfCharacter(
                    from: CharacterSet(charactersIn: "\n.!?"),
                    options: .backwards
                )
                if boundary.location != NSNotFound, boundary.location > maximumLength / 2 {
                    length = boundary.location + boundary.length
                }
            }
            let range = NSRange(location: location, length: length)
            result.append(Chunk(text: source.substring(with: range), utf16Offset: location))
            location += length
        }
        return result
    }
}
