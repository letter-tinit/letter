import Foundation
import SherpaOnnx
import SherpaOnnxC

enum SherpaOnnxEngineFactory {
    static func makeEngine(
        for descriptor: SherpaOnnxModelDescriptor
    ) throws -> SherpaOnnxOfflineTtsWrapper {
        let model = try makeModelConfig(for: descriptor)
        var config = sherpaOnnxOfflineTtsConfig(
            model: model,
            maxNumSentences: descriptor.maxNumSentences,
            silenceScale: descriptor.silenceScale
        )
        let engine = SherpaOnnxOfflineTtsWrapper(config: &config)
        guard engine.tts != nil else {
            throw SherpaOnnxEngineError.couldNotLoadModel(descriptor.id)
        }
        return engine
    }

    private static func makeModelConfig(
        for descriptor: SherpaOnnxModelDescriptor
    ) throws -> SherpaOnnxOfflineTtsModelConfig {
        switch descriptor.family {
        case .vits:
            return try makeVitsConfig(for: descriptor)
        case .matcha:
            return try makeMatchaConfig(for: descriptor)
        }
    }

    private static func makeVitsConfig(
        for descriptor: SherpaOnnxModelDescriptor
    ) throws -> SherpaOnnxOfflineTtsModelConfig {
        let config = try sherpaOnnxOfflineTtsVitsModelConfig(
            model: descriptor.requiredFile("model"),
            lexicon: descriptor.optionalFile("lexicon"),
            tokens: descriptor.requiredFile("tokens"),
            dataDir: descriptor.optionalFile("dataDir"),
            noiseScale: descriptor.floatParameter("noiseScale", default: 0.667),
            noiseScaleW: descriptor.floatParameter("noiseScaleW", default: 0.8),
            lengthScale: descriptor.floatParameter("lengthScale", default: 1),
            dictDir: descriptor.optionalFile("dictDir")
        )
        return sherpaOnnxOfflineTtsModelConfig(
            vits: config,
            numThreads: descriptor.numThreads
        )
    }

    private static func makeMatchaConfig(
        for descriptor: SherpaOnnxModelDescriptor
    ) throws -> SherpaOnnxOfflineTtsModelConfig {
        let config = try sherpaOnnxOfflineTtsMatchaModelConfig(
            acousticModel: descriptor.requiredFile("acousticModel"),
            vocoder: descriptor.requiredFile("vocoder"),
            lexicon: descriptor.optionalFile("lexicon"),
            tokens: descriptor.requiredFile("tokens"),
            dataDir: descriptor.optionalFile("dataDir"),
            noiseScale: descriptor.floatParameter("noiseScale", default: 0.667),
            lengthScale: descriptor.floatParameter("lengthScale", default: 1),
            dictDir: descriptor.optionalFile("dictDir")
        )
        return sherpaOnnxOfflineTtsModelConfig(
            matcha: config,
            numThreads: descriptor.numThreads
        )
    }

}

private enum SherpaOnnxEngineError: Error {
    case couldNotLoadModel(String)
}
