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

    static func makeBudgetContainer() throws -> ModelContainer {
        try ModelContainer(
            for: BudgetRecord.self,
            BudgetAllocationRecord.self,
            BudgetTransactionRecord.self,
            FixedExpensePlanRecord.self,
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
}
