import AVFoundation
import Foundation
import Domain

@MainActor
public final class GoogleCloudBookAudioExporter: BookAudioExportRepository {
    private let client: any GoogleCloudSpeechSynthesizing
    private let fileManager: FileManager
    private let exportRoot: URL

    public init(
        client: any GoogleCloudSpeechSynthesizing,
        fileManager: FileManager = .default
    ) {
        self.client = client
        self.fileManager = fileManager
        exportRoot = fileManager.temporaryDirectory
            .appendingPathComponent("LetterGoogleAudioExports", isDirectory: true)
    }

    public func export(
        book: Book,
        rate: Double,
        onProgress: @escaping (Double) -> Void
    ) async throws -> URL {
        let chunks = exportChunks(book: book)
        guard !chunks.isEmpty else { throw AudioBookExportError.emptyBook }
        let directory = exportRoot.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
        let outputURL = directory.appendingPathComponent(safeFilename(book.title) + ".m4a")
        let accumulator = M4AAudioAccumulator(url: outputURL)

        do {
            try await synthesize(
                chunks,
                book: book,
                rate: rate,
                directory: directory,
                accumulator: accumulator,
                onProgress: onProgress
            )
            accumulator.close()
            try await applyRemainingRateIfNeeded(to: outputURL, requestedRate: rate)
            onProgress(1)
            return outputURL
        } catch {
            accumulator.close()
            try? fileManager.removeItem(at: directory)
            throw error
        }
    }

    public func cancel() {}

    public func discardExport(at url: URL) {
        let rootPath = exportRoot.standardizedFileURL.path + "/"
        guard url.standardizedFileURL.path.hasPrefix(rootPath) else { return }
        try? fileManager.removeItem(at: url.deletingLastPathComponent())
    }

    private func exportChunks(book: Book) -> [SpeechTextChunker.Chunk] {
        book.chapters.flatMap {
            SpeechTextChunker().chunks(text: $0.content, startingAt: 0, maximumLength: 1_200)
        }
    }

    private func synthesize(
        _ chunks: [SpeechTextChunker.Chunk],
        book: Book,
        rate: Double,
        directory: URL,
        accumulator: M4AAudioAccumulator,
        onProgress: (Double) -> Void
    ) async throws {
        for (index, chunk) in chunks.enumerated() {
            try Task.checkCancellation()
            let audio = try await client.synthesize(
                GoogleCloudSpeechRequest(
                    text: chunk.text,
                    languageCode: book.language.languageCode,
                    rate: rate
                )
            )
            let chunkURL = directory.appendingPathComponent("chunk-\(index).mp3")
            try audio.write(to: chunkURL, options: .atomic)
            defer { try? fileManager.removeItem(at: chunkURL) }
            try accumulator.appendMP3(at: chunkURL)
            let synthesisFraction = rate > 2 ? 0.95 : 1
            onProgress(Double(index + 1) / Double(chunks.count) * synthesisFraction)
        }
    }

    private func applyRemainingRateIfNeeded(
        to outputURL: URL,
        requestedRate: Double
    ) async throws {
        let remainingRate = requestedRate / 2
        guard remainingRate > 1 else { return }
        let asset = AVURLAsset(url: outputURL)
        let sourceTrack = try await asset.loadTracks(withMediaType: .audio).first
        let duration = try await asset.load(.duration)
        let composition = AVMutableComposition()
        guard let sourceTrack,
              let track = composition.addMutableTrack(
                withMediaType: .audio,
                preferredTrackID: kCMPersistentTrackID_Invalid
              ) else { throw AudioBookExportError.encodingFailed }
        try track.insertTimeRange(CMTimeRange(start: .zero, duration: duration), of: sourceTrack, at: .zero)
        composition.scaleTimeRange(
            CMTimeRange(start: .zero, duration: duration),
            toDuration: CMTimeMultiplyByFloat64(duration, multiplier: 1 / remainingRate)
        )
        try await replaceWithExportedComposition(composition, outputURL: outputURL)
    }

    private func replaceWithExportedComposition(
        _ composition: AVMutableComposition,
        outputURL: URL
    ) async throws {
        guard let session = AVAssetExportSession(
            asset: composition,
            presetName: AVAssetExportPresetAppleM4A
        ) else { throw AudioBookExportError.encodingFailed }
        session.audioTimePitchAlgorithm = .spectral
        let adjustedURL = outputURL.deletingLastPathComponent()
            .appendingPathComponent("rate-adjusted.m4a")
        try await session.export(to: adjustedURL, as: .m4a)
        try fileManager.removeItem(at: outputURL)
        try fileManager.moveItem(at: adjustedURL, to: outputURL)
    }

    private func safeFilename(_ title: String) -> String {
        let invalid = CharacterSet(charactersIn: "/:\\?%*|\"<>")
        let value = title.components(separatedBy: invalid).joined(separator: "-")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return String((value.isEmpty ? "Audiobook" : value).prefix(100))
    }
}
