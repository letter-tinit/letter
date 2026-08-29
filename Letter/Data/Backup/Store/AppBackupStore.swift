import Foundation
import SwiftData

@MainActor
final class AppBackupStore {
    private let financeStore: FinanceBackupStore
    private let habitStore: HabitBackupStore

    init(modelContext: ModelContext) {
        financeStore = FinanceBackupStore(modelContext: modelContext)
        habitStore = HabitBackupStore(
            repository: ImpHabitRepository(modelContext: modelContext),
            notificationRepository: ImpHabitNotificationRepository()
        )
    }

    func exportBackup() throws -> AppBackup {
        let timestamp = UserDefaults.standard.double(forKey: FinanceSettings.earliestMonthKey)
        let earliestMonth = timestamp == 0
            ? FinanceMonth(.now).startDate
            : Date(timeIntervalSinceReferenceDate: timestamp)

        return AppBackup(
            schemaVersion: AppBackup.currentSchemaVersion,
            exportedAt: .now,
            earliestMonth: earliestMonth,
            finance: try financeStore.exportBackup(),
            habits: try habitStore.exportBackup()
        )
    }

    func importBackup(_ backup: AppBackup) throws {
        try backup.validate()

        let currentBackup = try exportBackup()
        _ = try writeSafetyBackup(currentBackup)

        do {
            try financeStore.importBackup(backup.finance)
            try habitStore.importBackup(backup.habits)
            if let earliestMonth = backup.earliestMonth {
                UserDefaults.standard.set(
                    FinanceMonth(earliestMonth).startDate.timeIntervalSinceReferenceDate,
                    forKey: FinanceSettings.earliestMonthKey
                )
            }
        } catch {
            // Best-effort restoration keeps the two domains consistent if the
            // second restore fails after the first domain has already saved.
            try? financeStore.importBackup(currentBackup.finance)
            try? habitStore.importBackup(currentBackup.habits)
            throw AppBackupError.restoreFailed
        }
    }

    func clearAllData() throws {
        try financeStore.clearAllData()
        try habitStore.clearAllData()
        UserDefaults.standard.removeObject(forKey: FinanceSettings.earliestMonthKey)
    }

    nonisolated static func encode(_ backup: AppBackup) throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        return try encoder.encode(backup)
    }

    nonisolated static func decode(_ data: Data) throws -> AppBackup {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode(AppBackup.self, from: data)
    }

    private func writeSafetyBackup(_ backup: AppBackup) throws -> URL {
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
        try Self.encode(backup).write(to: url, options: .atomic)
        return url
    }

    private static let filenameFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd-HHmmss"
        return formatter
    }()
}
