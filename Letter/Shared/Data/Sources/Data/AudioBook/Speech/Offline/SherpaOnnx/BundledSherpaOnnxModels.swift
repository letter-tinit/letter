import Foundation

public struct BundledSherpaOnnxModels: Sendable {
    let catalog: SherpaOnnxModelCatalog

    public init() {
        guard let root = Bundle.module.url(
            forResource: "OfflineSpeechModels",
            withExtension: nil
        ) else {
            preconditionFailure("Offline speech model resources are missing")
        }
        let manifestURL = root.appending(path: "models.json")
        guard FileManager.default.fileExists(atPath: manifestURL.path) else {
            preconditionFailure("Offline speech model manifest is missing")
        }
        do {
            catalog = try SherpaOnnxModelCatalog(
                manifestData: Data(contentsOf: manifestURL),
                rootDirectory: root
            )
        } catch {
            preconditionFailure("Invalid offline speech model manifest: \(error)")
        }
    }
}
