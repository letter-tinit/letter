import AVFoundation
import Foundation

@MainActor
final class ImpAudioBookRepository: NSObject, AudioBookRepository {
    private let synthesizer = AVSpeechSynthesizer()

    func speak(_ text: String) {
        synthesizer.stopSpeaking(at: .immediate)
        for chunk in text.speechChunks(maxLength: 2_000) {
            synthesizer.speak(AVSpeechUtterance(string: chunk))
        }
    }

    func pause() { synthesizer.pauseSpeaking(at: .word) }
    func resume() { synthesizer.continueSpeaking() }
    func stop() { synthesizer.stopSpeaking(at: .immediate) }
}

private extension String {
    func speechChunks(maxLength: Int) -> [String] {
        guard count > maxLength else { return [self] }
        var chunks: [String] = []
        var current = ""
        for paragraph in split(whereSeparator: \.isNewline) {
            let part = String(paragraph)
            if current.count + part.count + 1 > maxLength, !current.isEmpty {
                chunks.append(current)
                current = ""
            }
            current += current.isEmpty ? part : "\n\(part)"
        }
        if !current.isEmpty { chunks.append(current) }
        return chunks.isEmpty ? [self] : chunks
    }
}
