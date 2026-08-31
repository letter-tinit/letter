import Foundation

struct BackupSummary: Equatable, Sendable {
    let exportedAt: Date
    let transactionCount: Int
    let budgetCount: Int
    let netWorthSnapshotCount: Int
    let habitCount: Int
    let habitEntryCount: Int
}

struct BackupFile: Equatable, Sendable {
    let data: Data
}

struct BackupImport: Equatable, Sendable {
    let data: Data
    let summary: BackupSummary
}

enum BackupError: Error {
    case unsupportedSchemaVersion(Int)
    case invalidData
    case restoreFailed
}
