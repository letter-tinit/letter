import Foundation
import Domain

public struct BackupArchiveCodec {
    public init() {}

    public func encode(_ archive: BackupArchive) throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        return try encoder.encode(archive)
    }

    public func encodeValidated(_ archive: BackupArchive) throws -> Data {
        try archive.validate()
        return try encode(archive)
    }

    public func decode(_ data: Data) throws -> BackupArchive {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        do {
            return try decoder.decode(BackupArchive.self, from: data)
        } catch let error as BackupError {
            throw error
        } catch {
            throw BackupError.invalidData
        }
    }

    public func decodeValidated(_ data: Data) throws -> BackupArchive {
        let archive = try decode(data)
        try archive.validate()
        return archive
    }
}
