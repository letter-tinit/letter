import Foundation

enum SherpaOnnxModelFamily: String, Decodable, Sendable {
    case vits
    case matcha

    var requiredFiles: Set<String> {
        switch self {
        case .vits:
            ["model", "tokens"]
        case .matcha:
            ["acousticModel", "vocoder", "tokens"]
        }
    }
}

struct SherpaOnnxModelDescriptor: Sendable {
    let id: String
    let languageCodes: [String]
    let isDefault: Bool
    let family: SherpaOnnxModelFamily
    let files: [String: URL]
    let parameters: [String: Double]
    let preferredTextChunkLength: Int
    let silenceScale: Float
    let speakerID: Int
    let numThreads: Int
    let maxNumSentences: Int

    var engineCacheKey: String {
        let fileKey = files
            .map { "\($0.key)=\($0.value.path)" }
            .sorted()
            .joined(separator: "|")
        let parameterKey = parameters
            .map { "\($0.key)=\($0.value)" }
            .sorted()
            .joined(separator: "|")
        return [
            family.rawValue,
            fileKey,
            parameterKey,
            String(numThreads),
            String(maxNumSentences)
        ].joined(separator: "#")
    }

    func languageMatchScore(for languageCode: String) -> Int? {
        let requested = languageCode.lowercased()
        return languageCodes.compactMap { supportedCode -> Int? in
            let supported = supportedCode.lowercased()
            if requested == supported { return 10_000 + supported.count }
            if requested.hasPrefix(supported + "-") { return supported.count }
            if supported.hasPrefix(requested + "-") { return requested.count }
            return nil
        }.max()
    }

    func requiredFile(_ key: String) throws -> String {
        guard let url = files[key] else {
            throw SherpaOnnxModelCatalogError.missingFileKey(modelID: id, key: key)
        }
        return url.path
    }

    func optionalFile(_ key: String) -> String {
        files[key]?.path ?? ""
    }

    func floatParameter(_ key: String, default defaultValue: Float) -> Float {
        parameters[key].map(Float.init) ?? defaultValue
    }
}

struct SherpaOnnxModelCatalog: Sendable {
    let models: [SherpaOnnxModelDescriptor]
    private let fallbackModelID: String

    init(manifestData: Data, rootDirectory: URL) throws {
        let manifest = try JSONDecoder().decode(ModelManifest.self, from: manifestData)
        guard !manifest.models.isEmpty else {
            throw SherpaOnnxModelCatalogError.emptyCatalog
        }
        guard Set(manifest.models.map(\.id)).count == manifest.models.count else {
            throw SherpaOnnxModelCatalogError.duplicateModelID
        }

        let root = rootDirectory.standardizedFileURL
        models = try manifest.models.map { entry in
            try Self.resolve(entry: entry, rootDirectory: root)
        }
        guard models.contains(where: { $0.id == manifest.fallbackModelID }) else {
            throw SherpaOnnxModelCatalogError.invalidFallbackModel(
                manifest.fallbackModelID
            )
        }
        fallbackModelID = manifest.fallbackModelID
    }

    func model(for languageCode: String) -> SherpaOnnxModelDescriptor {
        let matchingModels = models.compactMap { model -> Match? in
            model.languageMatchScore(for: languageCode).map {
                Match(model: model, score: $0)
            }
        }
        let defaults = matchingModels.filter { $0.model.isDefault }
        return defaults.max(by: { $0.score < $1.score })?.model
            ?? matchingModels.max(by: { $0.score < $1.score })?.model
            ?? models.first(where: { $0.id == fallbackModelID })!
    }

    private struct Match {
        let model: SherpaOnnxModelDescriptor
        let score: Int
    }

    private static func resolve(
        entry: ModelManifest.Entry,
        rootDirectory: URL
    ) throws -> SherpaOnnxModelDescriptor {
        guard !entry.id.isEmpty, !entry.languageCodes.isEmpty else {
            throw SherpaOnnxModelCatalogError.invalidModel(entry.id)
        }
        guard entry.preferredTextChunkLength > 0,
              (0.01 ... 10).contains(entry.silenceScale),
              entry.speakerID >= 0,
              entry.numThreads > 0,
              entry.maxNumSentences == -1 || entry.maxNumSentences > 0 else {
            throw SherpaOnnxModelCatalogError.invalidModel(entry.id)
        }
        guard entry.family.requiredFiles.isSubset(of: Set(entry.files.keys)) else {
            let missing = entry.family.requiredFiles.subtracting(entry.files.keys).sorted()
            throw SherpaOnnxModelCatalogError.missingFileKey(
                modelID: entry.id,
                key: missing.joined(separator: ", ")
            )
        }

        let rootPath = rootDirectory.path.hasSuffix("/")
            ? rootDirectory.path
            : rootDirectory.path + "/"
        let files = try entry.files.reduce(into: [String: URL]()) { result, item in
            let url = rootDirectory.appending(path: item.value).standardizedFileURL
            guard url.path.hasPrefix(rootPath) else {
                throw SherpaOnnxModelCatalogError.invalidResourcePath(
                    modelID: entry.id,
                    path: item.value
                )
            }
            guard FileManager.default.fileExists(atPath: url.path) else {
                throw SherpaOnnxModelCatalogError.missingResource(
                    modelID: entry.id,
                    path: item.value
                )
            }
            result[item.key] = url
        }

        return SherpaOnnxModelDescriptor(
            id: entry.id,
            languageCodes: entry.languageCodes,
            isDefault: entry.isDefault,
            family: entry.family,
            files: files,
            parameters: entry.parameters,
            preferredTextChunkLength: entry.preferredTextChunkLength,
            silenceScale: entry.silenceScale,
            speakerID: entry.speakerID,
            numThreads: entry.numThreads,
            maxNumSentences: entry.maxNumSentences
        )
    }
}

private struct ModelManifest: Decodable {
    let fallbackModelID: String
    let models: [Entry]

    struct Entry: Decodable {
        let id: String
        let languageCodes: [String]
        let isDefault: Bool
        let family: SherpaOnnxModelFamily
        let files: [String: String]
        let parameters: [String: Double]
        let preferredTextChunkLength: Int
        let silenceScale: Float
        let speakerID: Int
        let numThreads: Int
        let maxNumSentences: Int
    }
}

enum SherpaOnnxModelCatalogError: Error, Equatable {
    case emptyCatalog
    case duplicateModelID
    case invalidFallbackModel(String)
    case invalidModel(String)
    case missingFileKey(modelID: String, key: String)
    case invalidResourcePath(modelID: String, path: String)
    case missingResource(modelID: String, path: String)
}
