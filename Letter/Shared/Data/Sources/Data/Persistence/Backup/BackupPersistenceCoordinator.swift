import Foundation
import Domain

@MainActor
public final class BackupPersistenceCoordinator {
    private let financePersistence: FinanceBackupPersistence
    private let habitPersistence: HabitBackupPersistence
    private let speechProviderSettings: any SpeechProviderSettingsRepository
    private let financeSettings: FinanceBackupSettingsStore
    private let safetyWriter: BackupSafetyWriter
    private let now: () -> Date

    public init(
        financePersistence: FinanceBackupPersistence,
        habitPersistence: HabitBackupPersistence,
        speechProviderSettings: any SpeechProviderSettingsRepository,
        financeSettings: FinanceBackupSettingsStore = FinanceBackupSettingsStore(),
        safetyWriter: BackupSafetyWriter = BackupSafetyWriter(),
        now: @escaping () -> Date = Date.init
    ) {
        self.financePersistence = financePersistence
        self.habitPersistence = habitPersistence
        self.speechProviderSettings = speechProviderSettings
        self.financeSettings = financeSettings
        self.safetyWriter = safetyWriter
        self.now = now
    }

    public func makeArchive() throws -> BackupArchive {
        BackupArchive(
            schemaVersion: BackupArchive.currentSchemaVersion,
            exportedAt: now(),
            earliestMonth: financeSettings.loadEarliestMonth(),
            finance: try financePersistence.exportBackup(),
            habits: try habitPersistence.exportBackup(),
            speechProviderSettings: SpeechProviderSettingsBackup(repository: speechProviderSettings)
        )
    }

    public func restoreArchive(_ archive: BackupArchive) throws {
        let currentArchive = try makeArchive()
        try safetyWriter.writeSafetyBackup(currentArchive)

        do {
            try replacePersistedData(with: archive)
            restoreSettings(from: archive)
        } catch {
            rollbackPersistedData(to: currentArchive)
            throw BackupError.restoreFailed
        }
    }

    public func clearAllData() throws {
        try financePersistence.clearAllData()
        try habitPersistence.clearAllData()
        financeSettings.clearEarliestMonth()
    }

    private func replacePersistedData(with archive: BackupArchive) throws {
        try financePersistence.importBackup(archive.finance)
        try habitPersistence.importBackup(archive.habits)
    }

    private func restoreSettings(from archive: BackupArchive) {
        archive.speechProviderSettings?.restore(to: speechProviderSettings)
        financeSettings.restoreEarliestMonth(archive.earliestMonth)
    }

    private func rollbackPersistedData(to archive: BackupArchive) {
        try? financePersistence.importBackup(archive.finance)
        try? habitPersistence.importBackup(archive.habits)
    }
}
