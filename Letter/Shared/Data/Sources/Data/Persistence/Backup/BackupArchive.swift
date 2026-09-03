import Foundation
import Domain
import Utility

public struct BackupArchive: Codable {
    public static let currentSchemaVersion = 1

    public let schemaVersion: Int
    public let exportedAt: Date
    public let earliestMonth: Date?
    public let finance: FinanceBackup
    public let habits: HabitBackup
    public let speechProviderSettings: SpeechProviderSettingsBackup?

    public var summary: BackupSummary {
        BackupSummary(
            exportedAt: exportedAt,
            transactionCount: finance.transactions.count,
            budgetCount: finance.budgets.count,
            netWorthSnapshotCount: finance.netWorthSnapshots.count,
            habitCount: habits.habits.count,
            habitEntryCount: habits.habits.reduce(0) { $0 + $1.entries.count }
        )
    }

    public func validate() throws {
        guard schemaVersion == Self.currentSchemaVersion else {
            throw BackupError.unsupportedSchemaVersion(schemaVersion)
        }
        guard finance.schemaVersion == FinanceBackup.schemaVersion else {
            throw BackupError.unsupportedSchemaVersion(finance.schemaVersion)
        }
        do {
            try habits.validate()
        } catch {
            throw BackupError.invalidData
        }
    }
}
