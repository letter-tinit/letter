import Foundation

struct HabitBackupService {
    func encode(_ backup: HabitBackup) throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        return try encoder.encode(backup)
    }

    func decodeAndValidate(from data: Data) throws -> HabitBackup {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let backup = try decoder.decode(HabitBackup.self, from: data)
        try backup.validate()
        return backup
    }

    func summary(for data: Data) throws -> HabitBackupSummary {
        try decodeAndValidate(from: data).summary
    }

    func safetyBackups() throws -> [URL] {
        try FileManager.default.contentsOfDirectory(
            at: backupDirectory(),
            includingPropertiesForKeys: [.creationDateKey],
            options: [.skipsHiddenFiles]
        )
        .filter { $0.pathExtension.lowercased() == "json" }
        .sorted { creationDate(for: $0) > creationDate(for: $1) }
    }

    func writePreImportBackup(data: Data, now: Date = Date()) throws -> URL {
        let filename = "HabitBackup-BeforeImport-\(Self.filenameDateFormatter.string(from: now)).json"
        let url = try backupDirectory().appendingPathComponent(filename)
        try data.write(to: url, options: .atomic)
        return url
    }
}

private extension HabitBackupService {
    static let filenameDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd-HHmmss"
        return formatter
    }()

    func backupDirectory() throws -> URL {
        let applicationSupportURL = try FileManager.default.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )
        let backupURL = applicationSupportURL.appendingPathComponent("Backups", isDirectory: true)
        try FileManager.default.createDirectory(at: backupURL, withIntermediateDirectories: true)
        return backupURL
    }

    func creationDate(for url: URL) -> Date {
        (try? url.resourceValues(forKeys: [.creationDateKey]))?.creationDate ?? .distantPast
    }
}
