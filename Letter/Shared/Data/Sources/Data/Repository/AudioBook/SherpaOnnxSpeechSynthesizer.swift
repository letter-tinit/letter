import Foundation
import SherpaOnnx
import Domain

struct OfflineSynthesizedAudio: Sendable {
    let waveData: Data
}

private enum OfflineSpeechSynthesisError: Error {
    case emptyAudio
}

protocol OfflineSpeechSynthesizing: Sendable {
    func synthesize(text: String, languageCode: String, rate: Double) async throws
        -> OfflineSynthesizedAudio
}

final class SherpaOnnxSpeechSynthesizer: OfflineSpeechSynthesizing, @unchecked Sendable {
    private enum Voice {
        case english
        case vietnamese
    }

    private let paths: OfflineSpeechModelPaths
    private let queue = DispatchQueue(label: "com.letter.offline-speech-synthesis", qos: .userInitiated)
    private var englishTTS: SherpaOnnxOfflineTtsWrapper?
    private var vietnameseTTS: SherpaOnnxOfflineTtsWrapper?

    init(paths: OfflineSpeechModelPaths) {
        self.paths = paths
    }

    func synthesize(
        text: String,
        languageCode: String,
        rate: Double
    ) async throws -> OfflineSynthesizedAudio {
        try await withCheckedThrowingContinuation { continuation in
            queue.async { [self] in
                do {
                    let voice: Voice = languageCode.lowercased().hasPrefix("vi")
                        ? .vietnamese
                        : .english
                    let tts = try engine(for: voice)
                    let config = SherpaOnnxGenerationConfigSwift(
                        silenceScale: 0.2,
                        speed: Float(min(max(rate, 0.5), 3)),
                        sid: 0
                    )
                    let generated = tts.generateWithConfig(
                        text: text,
                        config: config,
                        callback: nil,
                        arg: nil
                    )
                    let samples = generated.samples
                    guard !samples.isEmpty, generated.sampleRate > 0 else {
                        throw OfflineSpeechSynthesisError.emptyAudio
                    }
                    continuation.resume(
                        returning: OfflineSynthesizedAudio(
                            waveData: WaveEncoder.encode(
                                samples: samples,
                                sampleRate: Int(generated.sampleRate)
                            )
                        )
                    )
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    private func engine(for voice: Voice) throws -> SherpaOnnxOfflineTtsWrapper {
        switch voice {
        case .english:
            if let englishTTS { return englishTTS }
            let matcha = sherpaOnnxOfflineTtsMatchaModelConfig(
                acousticModel: paths.englishAcousticModel.path,
                vocoder: paths.englishVocoder.path,
                tokens: paths.englishTokens.path,
                dataDir: paths.englishEspeakData.path
            )
            let model = sherpaOnnxOfflineTtsModelConfig(
                matcha: matcha,
                numThreads: 2
            )
            var config = sherpaOnnxOfflineTtsConfig(
                model: model,
                maxNumSentences: 1,
                silenceScale: 0.2
            )
            let engine = SherpaOnnxOfflineTtsWrapper(config: &config)
            englishTTS = engine
            return engine
        case .vietnamese:
            if let vietnameseTTS { return vietnameseTTS }
            let vits = sherpaOnnxOfflineTtsVitsModelConfig(
                model: paths.vietnameseModel.path,
                tokens: paths.vietnameseTokens.path,
                dataDir: paths.vietnameseEspeakData.path
            )
            let model = sherpaOnnxOfflineTtsModelConfig(
                vits: vits,
                numThreads: 2
            )
            var config = sherpaOnnxOfflineTtsConfig(
                model: model,
                maxNumSentences: 1,
                silenceScale: 0.2
            )
            let engine = SherpaOnnxOfflineTtsWrapper(config: &config)
            vietnameseTTS = engine
            return engine
        }
    }

}

private enum WaveEncoder {
    static func encode(samples: [Float], sampleRate: Int) -> Data {
        let pcm = samples.map { sample -> Int16 in
            let clamped = min(max(sample, -1), 1)
            return Int16(clamped * Float(Int16.max))
        }
        let dataSize = UInt32(pcm.count * MemoryLayout<Int16>.size)
        var data = Data()
        data.appendASCII("RIFF")
        data.appendLittleEndian(UInt32(36) + dataSize)
        data.appendASCII("WAVEfmt ")
        data.appendLittleEndian(UInt32(16))
        data.appendLittleEndian(UInt16(1))
        data.appendLittleEndian(UInt16(1))
        data.appendLittleEndian(UInt32(sampleRate))
        data.appendLittleEndian(UInt32(sampleRate * 2))
        data.appendLittleEndian(UInt16(2))
        data.appendLittleEndian(UInt16(16))
        data.appendASCII("data")
        data.appendLittleEndian(dataSize)
        for sample in pcm { data.appendLittleEndian(UInt16(bitPattern: sample)) }
        return data
    }
}

private extension Data {
    mutating func appendASCII(_ string: String) {
        append(contentsOf: string.utf8)
    }

    mutating func appendLittleEndian<T: FixedWidthInteger>(_ value: T) {
        var value = value.littleEndian
        Swift.withUnsafeBytes(of: &value) { append(contentsOf: $0) }
    }
}
