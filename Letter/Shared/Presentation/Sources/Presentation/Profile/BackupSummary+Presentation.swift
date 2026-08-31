import Foundation
import Domain
import Utility
import Styleguide

public extension BackupSummary {
    public var message: String {
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
