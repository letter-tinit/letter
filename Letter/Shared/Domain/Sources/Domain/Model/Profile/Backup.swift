import Foundation
import Utility

public struct BackupSummary: Equatable, Sendable {
    public let exportedAt: Date
    public let transactionCount: Int
    public let budgetCount: Int
    public let netWorthCount: Int
    public let habitCount: Int
    public let habitEntryCount: Int
    
    public init(
        exportedAt: Date,
        transactionCount: Int,
        budgetCount: Int,
        netWorthCount: Int,
        habitCount: Int,
        habitEntryCount: Int
    ) {
        self.exportedAt = exportedAt
        self.transactionCount = transactionCount
        self.budgetCount = budgetCount
        self.netWorthCount = netWorthCount
        self.habitCount = habitCount
        self.habitEntryCount = habitEntryCount
    }
}

public struct BackupFile: Equatable, Sendable {
    public let data: Data
    public init(data: Data) { self.data = data }
}

public struct BackupImport: Equatable, Sendable {
    public let data: Data
    public let summary: BackupSummary
    public init(data: Data, summary: BackupSummary) { self.data = data; self.summary = summary }
}

public enum BackupError: Error {
    case unsupportedSchemaVersion(Int)
    case invalidData
    case restoreFailed
}
