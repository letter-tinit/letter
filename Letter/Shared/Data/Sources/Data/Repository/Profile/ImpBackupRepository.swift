import Foundation
import Domain

@MainActor
public final class ImpBackupRepository: BackupRepository {
    private let coordinator: BackupPersistenceCoordinator
    private let codec: BackupArchiveCodec
    private let fileReader: BackupFileReader

    public init(
        coordinator: BackupPersistenceCoordinator,
        codec: BackupArchiveCodec = BackupArchiveCodec(),
        fileReader: BackupFileReader = BackupFileReader()
    ) {
        self.coordinator = coordinator
        self.codec = codec
        self.fileReader = fileReader
    }

    public func exportBackup() throws -> BackupFile {
        BackupFile(data: try codec.encodeValidated(coordinator.makeArchive()))
    }

    public func inspectBackup(at url: URL) throws -> BackupImport {
        let data = try fileReader.readData(from: url)
        let archive = try codec.decodeValidated(data)
        return BackupImport(data: data, summary: archive.summary)
    }

    public func restoreBackup(_ data: Data) throws {
        try coordinator.restoreArchive(codec.decodeValidated(data))
    }

    public func clearAllData() throws {
        try coordinator.clearAllData()
    }
}
