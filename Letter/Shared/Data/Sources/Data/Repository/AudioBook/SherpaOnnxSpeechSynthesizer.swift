import Foundation
import SherpaOnnx

private enum OfflineSpeechSynthesisError: Error {
    case emptyAudio
}

public final class SherpaOnnxSpeechSynthesizer: LocalSpeechSynthesizing, @unchecked Sendable {
    private let catalog: SherpaOnnxModelCatalog
    private let queue = DispatchQueue(label: "com.letter.offline-speech-synthesis", qos: .userInitiated)
    private var engines: [String: SherpaOnnxOfflineTtsWrapper] = [:]

    public init(models: BundledSherpaOnnxModels) {
        catalog = models.catalog
    }

    public func preferredTextChunkLength(for languageCode: String) -> Int {
        catalog.model(for: languageCode).preferredTextChunkLength
    }

    public func synthesize(
        _ request: LocalSpeechSynthesisRequest
    ) async throws -> SynthesizedSpeechAudio {
        try await withCheckedThrowingContinuation { continuation in
            queue.async { [self] in
                do {
                    let model = catalog.model(for: request.languageCode)
                    let tts = try engine(for: model)
                    let config = SherpaOnnxGenerationConfigSwift(
                        silenceScale: model.silenceScale,
                        speed: Float(min(max(request.rateMultiplier, 0.5), 3)),
                        sid: model.speakerID
                    )
                    let generated = tts.generateWithConfig(
                        text: request.text,
                        config: config,
                        callback: nil,
                        arg: nil
                    )
                    let samples = generated.samples
                    guard !samples.isEmpty, generated.sampleRate > 0 else {
                        throw OfflineSpeechSynthesisError.emptyAudio
                    }
                    continuation.resume(
                        returning: SynthesizedSpeechAudio(
                            data: WaveEncoder.encode(
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

    private func engine(
        for model: SherpaOnnxModelDescriptor
    ) throws -> SherpaOnnxOfflineTtsWrapper {
        if let engine = engines[model.engineCacheKey] { return engine }
        let engine = try SherpaOnnxEngineFactory.makeEngine(for: model)
        engines[model.engineCacheKey] = engine
        return engine
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
