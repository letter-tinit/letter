import Foundation

struct BackupArchive: Codable {
    static let currentSchemaVersion = 1

    let schemaVersion: Int
    let exportedAt: Date
    let earliestMonth: Date?
    let finance: FinanceBackup
    let habits: HabitBackup

    var summary: BackupSummary {
        BackupSummary(
            exportedAt: exportedAt,
            transactionCount: finance.transactions.count,
            budgetCount: finance.budgets.count,
            netWorthSnapshotCount: finance.netWorthSnapshots.count,
            habitCount: habits.habits.count,
            habitEntryCount: habits.habits.reduce(0) { $0 + $1.entries.count }
        )
    }

    func validate() throws {
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
