import Foundation

public struct BackupSafetyWriter {
    private let fileManager: FileManager
    private let codec: BackupArchiveCodec
    private let now: () -> Date

    public init(
        fileManager: FileManager = .default,
        codec: BackupArchiveCodec = BackupArchiveCodec(),
        now: @escaping () -> Date = Date.init
    ) {
        self.fileManager = fileManager
        self.codec = codec
        self.now = now
    }

    public func writeSafetyBackup(_ archive: BackupArchive) throws {
        let applicationSupport = try fileManager.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )
        let directory = applicationSupport.appendingPathComponent("Backups", isDirectory: true)
        try fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
        let filename = "Letter-BeforeImport-\(Self.filenameFormatter.string(from: now())).json"
        let url = directory.appendingPathComponent(filename)
        try codec.encodeValidated(archive).write(to: url, options: .atomic)
    }

    private static let filenameFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd-HHmmss"
        return formatter
    }()
}
