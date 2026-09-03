import Foundation
import SwiftData
import Domain
import Utility

@MainActor
public final class ImpBackupRepository: BackupRepository {
    private let financePersistence: FinanceBackupPersistence
    private let habitPersistence: HabitBackupPersistence
    private let speechProviderSettings: any SpeechProviderSettingsRepository

    public init(
        modelContext: ModelContext,
        speechProviderSettings: any SpeechProviderSettingsRepository
    ) {
        self.speechProviderSettings = speechProviderSettings
        financePersistence = FinanceBackupPersistence(modelContext: modelContext)
        habitPersistence = HabitBackupPersistence(
            repository: ImpHabitRepository(modelContext: modelContext),
            notificationRepository: ImpHabitNotificationRepository()
        )
    }

    public func exportBackup() throws -> BackupFile {
        let archive = try makeArchive()
        return BackupFile(data: try encode(archive))
    }

    public func inspectBackup(at url: URL) throws -> BackupImport {
        let scoped = url.startAccessingSecurityScopedResource()
        defer { if scoped { url.stopAccessingSecurityScopedResource() } }
        let data: Data
        do {
            data = try Data(contentsOf: url)
        } catch {
            throw BackupError.invalidData
        }
        let archive = try decode(data)
        try archive.validate()
        return BackupImport(data: data, summary: archive.summary)
    }

    public func restoreBackup(_ data: Data) throws {
        let archive = try decode(data)
        try archive.validate()
        let currentArchive = try makeArchive()
        try writeSafetyBackup(currentArchive)

        do {
            try financePersistence.importBackup(archive.finance)
            try habitPersistence.importBackup(archive.habits)
            archive.speechProviderSettings?.restore(to: speechProviderSettings)
            restoreEarliestMonth(archive.earliestMonth)
        } catch {
            try? financePersistence.importBackup(currentArchive.finance)
            try? habitPersistence.importBackup(currentArchive.habits)
            throw BackupError.restoreFailed
        }
    }

    public func clearAllData() throws {
        try financePersistence.clearAllData()
        try habitPersistence.clearAllData()
        UserDefaults.standard.removeObject(forKey: FinanceSettings.earliestMonthKey)
    }

    private func makeArchive() throws -> BackupArchive {
        let timestamp = UserDefaults.standard.double(forKey: FinanceSettings.earliestMonthKey)
        let earliestMonth = timestamp == 0
            ? FinanceMonth(.now).startDate
            : Date(timeIntervalSinceReferenceDate: timestamp)
        return BackupArchive(
            schemaVersion: BackupArchive.currentSchemaVersion,
            exportedAt: .now,
            earliestMonth: earliestMonth,
            finance: try financePersistence.exportBackup(),
            habits: try habitPersistence.exportBackup(),
            speechProviderSettings: SpeechProviderSettingsBackup(repository: speechProviderSettings)
        )
    }

    private func restoreEarliestMonth(_ date: Date?) {
        guard let date else { return }
        UserDefaults.standard.set(
            FinanceMonth(date).startDate.timeIntervalSinceReferenceDate,
            forKey: FinanceSettings.earliestMonthKey
        )
    }

    private func encode(_ archive: BackupArchive) throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        return try encoder.encode(archive)
    }

    private func decode(_ data: Data) throws -> BackupArchive {
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

    private func writeSafetyBackup(_ archive: BackupArchive) throws {
        let applicationSupport = try FileManager.default.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )
        let directory = applicationSupport.appendingPathComponent("Backups", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let filename = "Letter-BeforeImport-\(Self.filenameFormatter.string(from: .now)).json"
        let url = directory.appendingPathComponent(filename)
        try encode(archive).write(to: url, options: .atomic)
    }

    private static let filenameFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd-HHmmss"
        return formatter
    }()
}
