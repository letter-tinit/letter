import Foundation
import VieNeuNanoModels

public struct BundledVieNeuNanoModels: Sendable {
    let modelDirectory: URL
    let g2pDictionary: URL

    public init() {
        let resources = VieNeuNanoModelResources()
        modelDirectory = resources.modelDirectory
        g2pDictionary = resources.g2pDictionary
    }
}
