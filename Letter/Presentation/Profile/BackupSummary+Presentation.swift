import Foundation

extension BackupSummary {
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
