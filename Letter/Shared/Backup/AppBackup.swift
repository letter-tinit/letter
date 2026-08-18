import Foundation

nonisolated struct AppBackup: Codable {
    static let currentSchemaVersion = 1

    let schemaVersion: Int
    let exportedAt: Date
    let finance: PersonalFinanceBackup
    let habits: HabitBackup
}

struct AppBackupSummary {
    let exportedAt: Date
    let transactionCount: Int
    let budgetCount: Int
    let netWorthYearCount: Int
    let habitCount: Int
    let habitEntryCount: Int

    var message: String {
        "app.backup.summary".localized(
            exportedAt.formatted(date: .abbreviated, time: .shortened),
            transactionCount,
            budgetCount,
            netWorthYearCount,
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
            netWorthYearCount: finance.netWorthYears.count,
            habitCount: habits.habits.count,
            habitEntryCount: habits.habits.reduce(0) { $0 + $1.entries.count }
        )
    }

    func validate() throws {
        guard schemaVersion == Self.currentSchemaVersion else {
            throw AppBackupError.unsupportedSchemaVersion(schemaVersion)
        }
        guard finance.schemaVersion == PersonalFinanceBackup.schemaVersion else {
            throw PersonalFinanceBackupStoreError.unsupportedSchemaVersion(finance.schemaVersion)
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
