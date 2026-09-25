import Foundation
import Domain

public struct BackupFileReader {
    public init() {}

    public func readData(from url: URL) throws -> Data {
        let scoped = url.startAccessingSecurityScopedResource()
        defer { if scoped { url.stopAccessingSecurityScopedResource() } }
        do {
            return try Data(contentsOf: url)
        } catch {
            throw BackupError.invalidData
        }
    }
}
