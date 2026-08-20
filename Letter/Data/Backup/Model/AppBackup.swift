import Foundation

nonisolated struct AppBackup: Codable {
    static let currentSchemaVersion = 1

    let schemaVersion: Int
    let exportedAt: Date
    let earliestMonth: Date?
    let finance: FinanceBackup
    let habits: HabitBackup
}

struct AppBackupSummary {
    let exportedAt: Date
    let transactionCount: Int
    let budgetCount: Int
    let netWorthSnapshotCount: Int
    let habitCount: Int
    let habitEntryCount: Int

    var message: String {
        "app.backup.summary".localized(
            exportedAt.formatted(date: .abbreviated, time: .shortened),
            transactionCount,
            budgetCount,
            netWorthSnapshotCount,
            habitCount,
            habitEntryCount
        )
    }
}

extension AppBackup {
    var summary: AppBackupSummary {
        AppBackupSummary(
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
            throw AppBackupError.unsupportedSchemaVersion(schemaVersion)
        }
        guard finance.schemaVersion == FinanceBackup.schemaVersion else {
            throw FinanceBackupStoreError.unsupportedSchemaVersion(finance.schemaVersion)
        }
        try habits.validate()
    }
}

enum AppBackupError: LocalizedError {
    case unsupportedSchemaVersion(Int)
    case restoreFailed

    var errorDescription: String? {
        switch self {
        case .unsupportedSchemaVersion(let version):
            "app.backup.error.unsupportedVersion".localized(version)
        case .restoreFailed:
            "app.backup.error.restore".localized
        }
    }
}
