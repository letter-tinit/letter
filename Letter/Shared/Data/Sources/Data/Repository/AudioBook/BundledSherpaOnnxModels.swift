import Foundation

public struct SherpaOnnxModelPaths: Sendable {
    public let rootDirectory: URL

    public var englishAcousticModel: URL {
        rootDirectory.appending(path: "matcha-icefall-en_US-ljspeech/model-steps-3.onnx")
    }

    public var englishVocoder: URL {
        rootDirectory.appending(path: "vocos-22khz-univ.onnx")
    }

    public var englishTokens: URL {
        rootDirectory.appending(path: "matcha-icefall-en_US-ljspeech/tokens.txt")
    }

    public var englishEspeakData: URL {
        rootDirectory.appending(path: "espeak-ng-data")
    }

    public var vietnameseModel: URL {
        rootDirectory.appending(
            path: "vits-piper-vi_VN-vais1000-medium/vi_VN-vais1000-medium.onnx"
        )
    }

    public var vietnameseTokens: URL {
        rootDirectory.appending(path: "vits-piper-vi_VN-vais1000-medium/tokens.txt")
    }

    public var vietnameseEspeakData: URL {
        rootDirectory.appending(path: "espeak-ng-data")
    }
}

public final class BundledSherpaOnnxModels: @unchecked Sendable {
    public let paths: SherpaOnnxModelPaths

    public init() {
        guard let root = Bundle.module.url(
            forResource: "OfflineSpeechModels",
            withExtension: nil
        ) else {
            preconditionFailure("Offline speech model resources are missing")
        }
        paths = SherpaOnnxModelPaths(rootDirectory: root)
    }
}
