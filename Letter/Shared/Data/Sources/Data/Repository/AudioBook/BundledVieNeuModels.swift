import Foundation

public struct BundledVieNeuModels: Sendable {
    let modelDirectory: URL
    let onnxDirectory: URL
    let codecDirectory: URL
    let voicesJSON: URL
    let g2pDictionary: URL

    public init() {
        guard let offlineModels = Bundle.module.url(
            forResource: "OfflineSpeechModels",
            withExtension: nil
        ) else {
            preconditionFailure("Offline speech model resources are missing")
        }
        let root = offlineModels.appending(path: "vieneu-v3-turbo")
        modelDirectory = root
        onnxDirectory = root.appending(path: "onnx")
        codecDirectory = root.appending(path: "codec")
        voicesJSON = root.appending(path: "voices_v3_turbo.json")
        g2pDictionary = root.appending(path: "sea_g2p.bin")
    }
}
