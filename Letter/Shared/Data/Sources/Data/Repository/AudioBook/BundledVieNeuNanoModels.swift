import Foundation

public struct BundledVieNeuNanoModels: Sendable {
    let modelDirectory: URL
    let g2pDictionary: URL

    public init() {
        guard let root = Bundle.module.url(
            forResource: "OfflineSpeechModels", withExtension: nil
        ) else {
            preconditionFailure("Offline speech model resources are missing")
        }
        modelDirectory = root.appending(path: "vieneu-v3-nano")
        // Both models use the same pinned bilingual SEA-G2P dictionary.
        g2pDictionary = root.appending(path: "vieneu-v3-turbo/sea_g2p.bin")
    }
}
