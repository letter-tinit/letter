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
        case .kokoro:
            return try makeKokoroConfig(for: descriptor)
        case .kitten:
            return try makeKittenConfig(for: descriptor)
        case .zipvoice:
            return try makeZipvoiceConfig(for: descriptor)
        case .pocket:
            return try makePocketConfig(for: descriptor)
        case .supertonic:
            return try makeSupertonicConfig(for: descriptor)
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

    private static func makeKokoroConfig(
        for descriptor: SherpaOnnxModelDescriptor
    ) throws -> SherpaOnnxOfflineTtsModelConfig {
        let config = try sherpaOnnxOfflineTtsKokoroModelConfig(
            model: descriptor.requiredFile("model"),
            voices: descriptor.requiredFile("voices"),
            tokens: descriptor.requiredFile("tokens"),
            dataDir: descriptor.optionalFile("dataDir"),
            lengthScale: descriptor.floatParameter("lengthScale", default: 1),
            dictDir: descriptor.optionalFile("dictDir"),
            lexicon: descriptor.optionalFile("lexicon"),
            lang: descriptor.option("lang")
        )
        return sherpaOnnxOfflineTtsModelConfig(
            kokoro: config,
            numThreads: descriptor.numThreads
        )
    }

    private static func makeKittenConfig(
        for descriptor: SherpaOnnxModelDescriptor
    ) throws -> SherpaOnnxOfflineTtsModelConfig {
        let config = try sherpaOnnxOfflineTtsKittenModelConfig(
            model: descriptor.requiredFile("model"),
            voices: descriptor.requiredFile("voices"),
            tokens: descriptor.requiredFile("tokens"),
            dataDir: descriptor.optionalFile("dataDir"),
            lengthScale: descriptor.floatParameter("lengthScale", default: 1)
        )
        return sherpaOnnxOfflineTtsModelConfig(
            numThreads: descriptor.numThreads,
            kitten: config
        )
    }

    private static func makeZipvoiceConfig(
        for descriptor: SherpaOnnxModelDescriptor
    ) throws -> SherpaOnnxOfflineTtsModelConfig {
        let config = try sherpaOnnxOfflineTtsZipvoiceModelConfig(
            tokens: descriptor.requiredFile("tokens"),
            encoder: descriptor.requiredFile("encoder"),
            decoder: descriptor.requiredFile("decoder"),
            vocoder: descriptor.requiredFile("vocoder"),
            dataDir: descriptor.optionalFile("dataDir"),
            lexicon: descriptor.optionalFile("lexicon"),
            featScale: descriptor.floatParameter("featScale", default: 0.1),
            tShift: descriptor.floatParameter("tShift", default: 0.5),
            targetRms: descriptor.floatParameter("targetRms", default: 0.1),
            guidanceScale: descriptor.floatParameter("guidanceScale", default: 1)
        )
        return sherpaOnnxOfflineTtsModelConfig(
            numThreads: descriptor.numThreads,
            zipvoice: config
        )
    }

    private static func makePocketConfig(
        for descriptor: SherpaOnnxModelDescriptor
    ) throws -> SherpaOnnxOfflineTtsModelConfig {
        let config = try sherpaOnnxOfflineTtsPocketModelConfig(
            lmFlow: descriptor.requiredFile("lmFlow"),
            lmMain: descriptor.requiredFile("lmMain"),
            encoder: descriptor.requiredFile("encoder"),
            decoder: descriptor.requiredFile("decoder"),
            textConditioner: descriptor.requiredFile("textConditioner"),
            vocabJson: descriptor.requiredFile("vocabJson"),
            tokenScoresJson: descriptor.requiredFile("tokenScoresJson"),
            voiceEmbeddingCacheCapacity: descriptor.intParameter(
                "voiceEmbeddingCacheCapacity",
                default: 50
            )
        )
        return sherpaOnnxOfflineTtsModelConfig(
            numThreads: descriptor.numThreads,
            pocket: config
        )
    }

    private static func makeSupertonicConfig(
        for descriptor: SherpaOnnxModelDescriptor
    ) throws -> SherpaOnnxOfflineTtsModelConfig {
        let config = try sherpaOnnxOfflineTtsSupertonicModelConfig(
            durationPredictor: descriptor.requiredFile("durationPredictor"),
            textEncoder: descriptor.requiredFile("textEncoder"),
            vectorEstimator: descriptor.requiredFile("vectorEstimator"),
            vocoder: descriptor.requiredFile("vocoder"),
            ttsJson: descriptor.requiredFile("ttsJson"),
            unicodeIndexer: descriptor.requiredFile("unicodeIndexer"),
            voiceStyle: descriptor.requiredFile("voiceStyle")
        )
        return sherpaOnnxOfflineTtsModelConfig(
            numThreads: descriptor.numThreads,
            supertonic: config
        )
    }
}

private enum SherpaOnnxEngineError: Error {
    case couldNotLoadModel(String)
}
