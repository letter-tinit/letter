import Foundation
import VieNeuTurboModels

public struct BundledVieNeuModels: Sendable {
    let modelDirectory: URL
    let onnxDirectory: URL
    let codecDirectory: URL
    let voicesJSON: URL
    let g2pDictionary: URL

    public init() {
        let resources = VieNeuTurboModelResources()
        modelDirectory = resources.modelDirectory
        onnxDirectory = resources.onnxDirectory
        codecDirectory = resources.codecDirectory
        voicesJSON = resources.voicesJSON
        g2pDictionary = resources.g2pDictionary
    }
}
