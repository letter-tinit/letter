import AVFoundation
import Foundation
import Domain
import Core
import Utility

@MainActor
public final class AppleBookAudioExporter: BookAudioExportRepository {
    private let synthesizer = AVSpeechSynthesizer()
    private let exportRoot: URL
    private var activeGate: AudioBufferWriteGate?

    public init(fileManager: FileManager = .default) {
        exportRoot = fileManager.temporaryDirectory
            .appendingPathComponent("LetterAudioExports", isDirectory: true)
    }

    public func export(
        book: Book,
        rate: Double,
        onProgress: @escaping (Double) -> Void
    ) async throws -> URL {
        let chunks = exportChunks(for: book)
        guard !chunks.isEmpty else { throw AudioBookExportError.emptyBook }
        let outputURL = try prepareOutputURL(bookTitle: book.title)
        let accumulator = M4AAudioAccumulator(url: outputURL)

        do {
            try await render(
                chunks,
                language: book.language,
                rate: rate,
                accumulator: accumulator,
                onProgress: onProgress
            )
            accumulator.close()
            return outputURL
        } catch {
            accumulator.close()
            try? FileManager.default.removeItem(at: outputURL.deletingLastPathComponent())
            throw error
        }
    }

    public func cancel() {
        synthesizer.stopSpeaking(at: .immediate)
        activeGate?.resume(throwing: CancellationError())
        activeGate = nil
    }

    public func discardExport(at url: URL) {
        let rootPath = exportRoot.standardizedFileURL.path + "/"
        guard url.standardizedFileURL.path.hasPrefix(rootPath) else { return }
        try? FileManager.default.removeItem(at: url.deletingLastPathComponent())
    }

    private func exportChunks(for book: Book) -> [String] {
        book.chapters.flatMap { chapter in
            SpeechTextChunker().chunks(
                text: chapter.content,
                startingAt: 0,
                maximumLength: 2_000
            ).map(\.text)
        }
    }

    private func render(
        _ chunks: [String],
        language: BookLanguage,
        rate: Double,
        accumulator: M4AAudioAccumulator,
        onProgress: (Double) -> Void
    ) async throws {
        let voice = AVSpeechSynthesisVoice(language: language.languageCode)
        for (index, chunk) in chunks.enumerated() {
            try Task.checkCancellation()
            let utterance = AVSpeechUtterance(string: chunk)
            utterance.voice = voice
            utterance.rate = appleSpeechRate(multiplier: rate)
            try await synthesize(utterance, accumulator: accumulator)
            onProgress(Double(index + 1) / Double(chunks.count))
        }
    }

    private func prepareOutputURL(bookTitle: String) throws -> URL {
        let directory = exportRoot.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(
            at: directory,
            withIntermediateDirectories: true
        )
        return directory.appendingPathComponent(safeFilename(bookTitle) + ".m4a")
    }

    private func synthesize(
        _ utterance: AVSpeechUtterance,
        accumulator: M4AAudioAccumulator
    ) async throws {
        defer { activeGate = nil }
        try await withCheckedThrowingContinuation { continuation in
            let gate = AudioBufferWriteGate(
                continuation: continuation,
                accumulator: accumulator
            )
            activeGate = gate
            synthesizer.write(utterance) { buffer in
                gate.consume(buffer)
            }
        }
    }

    private func safeFilename(_ title: String) -> String {
        let invalid = CharacterSet(charactersIn: "/:\\?%*|\"<>")
        let value = title.components(separatedBy: invalid).joined(separator: "-")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return String((value.isEmpty ? "Audiobook" : value).prefix(100))
    }
}

private final class M4AAudioAccumulator: @unchecked Sendable {
    private let url: URL
    private let lock = NSLock()
    private var file: AVAudioFile?

    public init(url: URL) {
        self.url = url
    }

    public func append(_ buffer: AVAudioPCMBuffer) throws {
        lock.lock()
        defer { lock.unlock() }
        if file == nil {
            file = try AVAudioFile(
                forWriting: url,
                settings: [
                    AVFormatIDKey: kAudioFormatMPEG4AAC,
                    AVSampleRateKey: buffer.format.sampleRate,
                    AVNumberOfChannelsKey: Int(buffer.format.channelCount),
                    AVEncoderBitRateKey: 64_000
                ],
                commonFormat: buffer.format.commonFormat,
                interleaved: buffer.format.isInterleaved
            )
        }
        try file?.write(from: buffer)
    }

    public func close() {
        lock.lock()
        file = nil
        lock.unlock()
    }
}

private final class AudioBufferWriteGate: @unchecked Sendable {
    private let lock = NSLock()
    private var continuation: CheckedContinuation<Void, Error>?
    private let accumulator: M4AAudioAccumulator

    public init(
        continuation: CheckedContinuation<Void, Error>,
        accumulator: M4AAudioAccumulator
    ) {
        self.continuation = continuation
        self.accumulator = accumulator
    }

    public func consume(_ buffer: AVAudioBuffer) {
        guard let pcmBuffer = buffer as? AVAudioPCMBuffer else {
            resume(throwing: AudioBookExportError.synthesisFailed)
            return
        }
        guard pcmBuffer.frameLength > 0 else {
            resume()
            return
        }
        do {
            try accumulator.append(pcmBuffer)
        } catch {
            resume(throwing: AudioBookExportError.encodingFailed)
        }
    }

    public func resume(throwing error: Error? = nil) {
        lock.lock()
        guard let continuation else {
            lock.unlock()
            return
        }
        self.continuation = nil
        lock.unlock()
        if let error { continuation.resume(throwing: error) }
        else { continuation.resume() }
    }
}
