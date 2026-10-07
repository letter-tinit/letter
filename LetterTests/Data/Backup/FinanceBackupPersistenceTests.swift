import Foundation
import SwiftData
import XCTest
@testable import Data
@testable import Domain

@MainActor
final class FinanceBackupPersistenceTests: XCTestCase {
    func test_importBackup_replacesExistingDataAndRestoresRecordGraph() throws {
        let context = try makeContext()
        let persistence = FinanceBackupPersistence(modelContext: context)
        context.insert(TransactionRecord(
            id: uuid(900),
            note: "old",
            type: .expense,
            category: .food,
            method: .cash,
            amount: 1,
            occurredAt: date(1),
            createAt: date(1)
        ))
        try context.save()

        let backup = makeFinanceBackup()

        try persistence.importBackup(backup)

        let transactions = try context.fetch(FetchDescriptor<TransactionRecord>())
        XCTAssertEqual(transactions.map(\.id), [uuid(1)])
        XCTAssertEqual(transactions[0].note, "Salary")
        XCTAssertEqual(transactions[0].amount, 1_000)

        let budgets = try context.fetch(FetchDescriptor<BudgetRecord>())
        let budget = try XCTUnwrap(budgets.first)
        XCTAssertEqual(budgets.count, 1)
        XCTAssertEqual(budget.id, uuid(10))
        XCTAssertEqual(budget.isLocked, false)

        let allocation = try XCTUnwrap(budget.allocations.first)
        let budgetTransaction = try XCTUnwrap(budget.transactions.first)
        let plan = try XCTUnwrap(budget.fixedExpensePlans.first)
        XCTAssertTrue(budgetTransaction.allocation === allocation)
        XCTAssertTrue(plan.allocation === allocation)
        XCTAssertTrue(plan.transaction === budgetTransaction)
        XCTAssertTrue(budgetTransaction.fixedExpensePlan === plan)
        XCTAssertTrue(allocation.transactions.contains { $0 === budgetTransaction })
        XCTAssertTrue(allocation.fixedExpensePlans.contains { $0 === plan })

        let planItems = try context.fetch(FetchDescriptor<NetWorthPlanItemRecord>())
        let planItem = try XCTUnwrap(planItems.first)
        let snapshots = try context.fetch(FetchDescriptor<NetWorthSnapshotRecord>())
        let snapshot = try XCTUnwrap(snapshots.first)
        let value = try XCTUnwrap(snapshot.values.first)
        XCTAssertEqual(snapshot.isLocked, false)
        XCTAssertTrue(value.planItem === planItem)
        XCTAssertTrue(value.snapshot === snapshot)

        let balanceMonths = try context.fetch(FetchDescriptor<BalanceMonthRecord>())
        XCTAssertEqual(balanceMonths.map(\.monthStart), [FinanceMonth(date(800)).startDate])
    }

    func test_exportBackup_sortsRecordsAndMapsRelationships() throws {
        let context = try makeContext()
        let persistence = FinanceBackupPersistence(modelContext: context)
        insertFinanceGraph(into: context)
        try context.save()

        let backup = try persistence.exportBackup()

        XCTAssertEqual(backup.schemaVersion, FinanceBackup.schemaVersion)
        XCTAssertEqual(backup.transactions.map(\.id), [uuid(2), uuid(1)])
        XCTAssertEqual(backup.budgets.map(\.id), [uuid(10)])
        let budget = try XCTUnwrap(backup.budgets.first)
        XCTAssertEqual(budget.allocations.map(\.id), [uuid(11)])
        XCTAssertEqual(budget.transactions.map(\.id), [uuid(12)])
        XCTAssertEqual(budget.fixedExpensePlans.map(\.id), [uuid(13)])
        XCTAssertEqual(budget.allocations[0].transactions, [uuid(12)])
        XCTAssertEqual(budget.allocations[0].fixedExpensePlans, [uuid(13)])
        XCTAssertEqual(budget.fixedExpensePlans[0].transactionID, uuid(12))
        XCTAssertEqual(budget.transactions[0].fixedExpensePlanID, uuid(13))
        XCTAssertEqual(backup.netWorthPlanItems.map(\.id), [uuid(20)])
        XCTAssertEqual(backup.netWorthSnapshots.map(\.id), [uuid(21)])
        XCTAssertEqual(backup.netWorthSnapshots[0].values.map(\.planItemID), [uuid(20)])
        XCTAssertEqual(backup.balanceMonths?.map(\.monthStart), [FinanceMonth(date(800)).startDate])
    }

    func test_importBackup_usesLegacyLockDefaultsAndAcceptsMissingBalanceMonths() throws {
        let context = try makeContext()
        let persistence = FinanceBackupPersistence(modelContext: context)
        let backup = FinanceBackup(
            schemaVersion: FinanceBackup.schemaVersion,
            backupDate: date(100),
            transactions: [],
            budgets: [
                BudgetBackup(
                    id: uuid(30),
                    periodStart: date(300),
                    income: 10,
                    method: .sixJars,
                    createdAt: date(301),
                    isLocked: nil,
                    allocations: [],
                    fixedExpensePlans: [],
                    transactions: []
                )
            ],
            netWorthPlanItems: [],
            netWorthSnapshots: [
                NetWorthSnapshotBackup(id: uuid(31), asOfDate: date(400), values: [], isLocked: nil)
            ],
            balanceMonths: nil
        )

        try persistence.importBackup(backup)

        XCTAssertEqual(try context.fetch(FetchDescriptor<BudgetRecord>()).first?.isLocked, true)
        XCTAssertEqual(try context.fetch(FetchDescriptor<NetWorthSnapshotRecord>()).first?.isLocked, true)
        XCTAssertTrue(try context.fetch(FetchDescriptor<BalanceMonthRecord>()).isEmpty)
    }

    func test_importBackup_rejectsUnsupportedSchemaBeforeClearingExistingData() throws {
        let context = try makeContext()
        let persistence = FinanceBackupPersistence(modelContext: context)
        context.insert(TransactionRecord(
            id: uuid(40),
            note: "keep",
            type: .income,
            category: .salary,
            method: .banking,
            amount: 1,
            occurredAt: date(1),
            createAt: date(1)
        ))
        try context.save()
        let backup = FinanceBackup(
            schemaVersion: FinanceBackup.schemaVersion + 1,
            backupDate: date(100),
            transactions: [],
            budgets: [],
            netWorthPlanItems: [],
            netWorthSnapshots: [],
            balanceMonths: []
        )

        XCTAssertThrowsError(try persistence.importBackup(backup)) { error in
            guard case FinanceBackupPersistenceError.unsupportedSchemaVersion(FinanceBackup.schemaVersion + 1) = error else {
                XCTFail("Unexpected error: \(error)")
                return
            }
        }
        XCTAssertEqual(try context.fetch(FetchDescriptor<TransactionRecord>()).map(\.id), [uuid(40)])
    }

    func test_clearAllData_removesEveryFinanceRecordType() throws {
        let context = try makeContext()
        let persistence = FinanceBackupPersistence(modelContext: context)
        insertFinanceGraph(into: context)
        try context.save()

        try persistence.clearAllData()

        XCTAssertTrue(try context.fetch(FetchDescriptor<TransactionRecord>()).isEmpty)
        XCTAssertTrue(try context.fetch(FetchDescriptor<BudgetRecord>()).isEmpty)
        XCTAssertTrue(try context.fetch(FetchDescriptor<BudgetAllocationRecord>()).isEmpty)
        XCTAssertTrue(try context.fetch(FetchDescriptor<BudgetTransactionRecord>()).isEmpty)
        XCTAssertTrue(try context.fetch(FetchDescriptor<FixedExpensePlanRecord>()).isEmpty)
        XCTAssertTrue(try context.fetch(FetchDescriptor<NetWorthPlanItemRecord>()).isEmpty)
        XCTAssertTrue(try context.fetch(FetchDescriptor<NetWorthSnapshotRecord>()).isEmpty)
        XCTAssertTrue(try context.fetch(FetchDescriptor<NetWorthValueRecord>()).isEmpty)
        XCTAssertTrue(try context.fetch(FetchDescriptor<BalanceMonthRecord>()).isEmpty)
    }

    private func makeContext() throws -> ModelContext {
        try ModelContext(FinanceRepositoryTestSupport.makeBackupContainer())
    }
}

@MainActor
private func insertFinanceGraph(into context: ModelContext) {
    context.insert(TransactionRecord(
        id: uuid(1),
        note: "Salary",
        type: .income,
        category: .salary,
        method: .banking,
        amount: 1_000,
        occurredAt: date(100),
        createAt: date(100)
    ))
    context.insert(TransactionRecord(
        id: uuid(2),
        note: "Bonus",
        type: .income,
        category: .salary,
        method: .banking,
        amount: 2_000,
        occurredAt: date(200),
        createAt: date(200)
    ))

    let budget = BudgetRecord(
        id: uuid(10),
        periodStart: date(500),
        income: 3_000,
        isLocked: false,
        method: .fiftyThirtyTwenty,
        createdAt: date(501)
    )
    let allocation = BudgetAllocationRecord(id: uuid(11), kind: .needs, ratio: 0.5, targetAmount: 1_500)
    let budgetTransaction = BudgetTransactionRecord(
        id: uuid(12),
        type: .expense,
        title: "Rent",
        note: "September",
        occurredAt: date(600),
        amount: 700,
        paymentMethod: .banking
    )
    let plan = FixedExpensePlanRecord(id: uuid(13), name: "Rent", amount: 700, amountType: .fixed)
    allocation.budget = budget
    budgetTransaction.budget = budget
    budgetTransaction.allocation = allocation
    budgetTransaction.fixedExpensePlan = plan
    plan.budget = budget
    plan.allocation = allocation
    plan.transaction = budgetTransaction
    budget.allocations = [allocation]
    budget.transactions = [budgetTransaction]
    budget.fixedExpensePlans = [plan]
    allocation.transactions = [budgetTransaction]
    allocation.fixedExpensePlans = [plan]
    context.insert(budget)
    context.insert(allocation)
    context.insert(budgetTransaction)
    context.insert(plan)

    let planItem = NetWorthPlanItemRecord(
        id: uuid(20),
        category: .cashAndBank,
        name: "Cash",
        displayOrder: 1
    )
    let snapshot = NetWorthSnapshotRecord(id: uuid(21), asOfDate: date(700), isLocked: false)
    let value = NetWorthValueRecord(id: uuid(22), amount: 5_000)
    value.planItem = planItem
    value.snapshot = snapshot
    planItem.values = [value]
    snapshot.values = [value]
    context.insert(planItem)
    context.insert(snapshot)
    context.insert(value)

    context.insert(BalanceMonthRecord(monthStart: date(800), isLocked: true))
}

private func makeFinanceBackup() -> FinanceBackup {
    FinanceBackup(
        schemaVersion: FinanceBackup.schemaVersion,
        backupDate: date(100),
        transactions: [
            TransactionBackup(
                id: uuid(1),
                note: "Salary",
                type: .income,
                category: .salary,
                method: .banking,
                amount: 1_000,
                occurredAt: date(100),
                createAt: date(100)
            )
        ],
        budgets: [
            BudgetBackup(
                id: uuid(10),
                periodStart: date(500),
                income: 3_000,
                method: .fiftyThirtyTwenty,
                createdAt: date(501),
                isLocked: false,
                allocations: [
                    BudgetAllocationBackup(
                        id: uuid(11),
                        kind: .needs,
                        ratio: 0.5,
                        targetAmount: 1_500,
                        transactions: [uuid(12)],
                        fixedExpensePlans: [uuid(13)]
                    )
                ],
                fixedExpensePlans: [
                    FixedExpensePlanBackup(
                        id: uuid(13),
                        allocationID: uuid(11),
                        name: "Rent",
                        amount: 700,
                        amountType: .fixed,
                        transactionID: uuid(12)
                    )
                ],
                transactions: [
                    BudgetTransactionBackup(
                        id: uuid(12),
                        allocationID: uuid(11),
                        type: .expense,
                        title: "Rent",
                        note: "September",
                        occurredAt: date(600),
                        amount: 700,
                        paymentMethod: .banking,
                        fixedExpensePlanID: uuid(13)
                    )
                ]
            )
        ],
        netWorthPlanItems: [
            NetWorthPlanItemBackup(
                id: uuid(20),
                category: .cashAndBank,
                name: "Cash",
                displayOrder: 1
            )
        ],
        netWorthSnapshots: [
            NetWorthSnapshotBackup(
                id: uuid(21),
                asOfDate: date(700),
                values: [NetWorthValueBackup(id: uuid(22), amount: 5_000, planItemID: uuid(20))],
                isLocked: false
            )
        ],
        balanceMonths: [BalanceMonthBackup(monthStart: date(800), isLocked: true)]
    )
}

private func uuid(_ value: Int) -> UUID {
    UUID(uuidString: String(format: "00000000-0000-0000-0000-%012d", value))!
}

private func date(_ value: TimeInterval) -> Date {
    Date(timeIntervalSince1970: value)
}
