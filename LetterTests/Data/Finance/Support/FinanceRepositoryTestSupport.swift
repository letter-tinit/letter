import SwiftData
@testable import Data

@MainActor
enum FinanceRepositoryTestSupport {
    static func makeBalanceContainer() throws -> ModelContainer {
        try ModelContainer(
            for: TransactionRecord.self,
            BalanceMonthRecord.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
    }

    static func makeNetWorthContainer() throws -> ModelContainer {
        try ModelContainer(
            for: NetWorthPlanItemRecord.self,
            NetWorthValueRecord.self,
            NetWorthSnapshotRecord.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
    }

    static func makeBackupContainer() throws -> ModelContainer {
        try ModelContainer(
            for: TransactionRecord.self,
            BalanceMonthRecord.self,
            NetWorthPlanItemRecord.self,
            NetWorthValueRecord.self,
            NetWorthSnapshotRecord.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
    }
}
