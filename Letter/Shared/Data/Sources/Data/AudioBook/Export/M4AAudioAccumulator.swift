import AVFoundation
import Foundation
import Domain

final class M4AAudioAccumulator: @unchecked Sendable {
    private let url: URL
    private let lock = NSLock()
    private var file: AVAudioFile?

    init(url: URL) {
        self.url = url
    }

    func append(_ buffer: AVAudioPCMBuffer) throws {
        try lock.withLock {
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
    }

    func appendMP3(at url: URL) throws {
        let input = try AVAudioFile(forReading: url)
        while input.framePosition < input.length {
            guard let buffer = AVAudioPCMBuffer(
                pcmFormat: input.processingFormat,
                frameCapacity: 8_192
            ) else { throw AudioBookExportError.encodingFailed }
            try input.read(into: buffer)
            guard buffer.frameLength > 0 else { break }
            try append(buffer)
        }
    }

    func close() {
        lock.withLock { file = nil }
    }
}
