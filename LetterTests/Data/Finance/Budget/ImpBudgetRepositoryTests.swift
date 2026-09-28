import Foundation
import SwiftData
import XCTest
@testable import Data
@testable import Domain

@MainActor
final class ImpBudgetRepositoryTests: XCTestCase {
    func test_saveBudget_roundTripsRelationships() throws {
        let repository = try makeRepository()
        let budget = makeBudget()

        try repository.saveBudget(budget)

        let fetched = try XCTUnwrap(repository.fetchBudget(id: budget.id))
        XCTAssertEqual(fetched.id, budget.id)
        XCTAssertEqual(fetched.periodStart, budget.periodStart)
        XCTAssertEqual(fetched.income, budget.income)
        XCTAssertEqual(fetched.isLocked, true)
        XCTAssertEqual(fetched.method, .fiftyThirtyTwenty)

        let allocation = try XCTUnwrap(fetched.allocations.first { $0.id == uuid(2) })
        XCTAssertEqual(allocation.kind, .needs)
        XCTAssertEqual(allocation.ratio, 0.5)
        XCTAssertEqual(allocation.targetAmount, 500)
        XCTAssertTrue(allocation.budget === fetched)

        let plan = try XCTUnwrap(fetched.fixedExpensePlans.first { $0.id == uuid(3) })
        XCTAssertEqual(plan.name, "Rent")
        XCTAssertEqual(plan.amount, 300)
        XCTAssertEqual(plan.amountType, .fixed)
        XCTAssertTrue(plan.budget === fetched)
        XCTAssertTrue(plan.allocation === allocation)

        let transaction = try XCTUnwrap(fetched.transactions.first { $0.id == uuid(4) })
        XCTAssertEqual(transaction.title, "Rent paid")
        XCTAssertEqual(transaction.note, "September")
        XCTAssertEqual(transaction.amount, 300)
        XCTAssertEqual(transaction.paymentMethod, .banking)
        XCTAssertTrue(transaction.budget === fetched)
        XCTAssertTrue(transaction.allocation === allocation)
        XCTAssertTrue(transaction.fixedExpensePlan === plan)
        XCTAssertTrue(plan.transaction === transaction)
        XCTAssertTrue(allocation.transactions.contains { $0 === transaction })
        XCTAssertTrue(allocation.fixedExpensePlans.contains { $0 === plan })
    }

    func test_fetchBudgets_sortsByPeriodStartDescending() throws {
        let repository = try makeRepository()
        let older = makeBudget(id: uuid(10), periodStart: date(100))
        let newer = makeBudget(id: uuid(11), periodStart: date(200))
        try repository.saveBudget(older)
        try repository.saveBudget(newer)

        XCTAssertEqual(try repository.fetchBudgets().map(\.id), [newer.id, older.id])
    }

    func test_saveBudget_replacesExistingRecordGraph() throws {
        let repository = try makeRepository()
        let original = makeBudget(id: uuid(20))
        try repository.saveBudget(original)

        let updated = Budget(
            id: original.id,
            periodStart: original.periodStart,
            income: 2_000,
            method: .sixJars,
            createdAt: original.createdAt
        )
        updated.isLocked = false
        let allocation = BudgetAllocation(
            id: uuid(21),
            budget: updated,
            kind: .necessities,
            ratio: 0.55,
            targetAmount: 1_100
        )
        updated.allocations = [allocation]

        try repository.saveBudget(updated)

        let fetched = try XCTUnwrap(repository.fetchBudget(id: original.id))
        XCTAssertEqual(fetched.income, 2_000)
        XCTAssertEqual(fetched.method, .sixJars)
        XCTAssertEqual(fetched.allocations.map(\.id), [allocation.id])
        XCTAssertTrue(fetched.transactions.isEmpty)
        XCTAssertTrue(fetched.fixedExpensePlans.isEmpty)
    }

    func test_deleteBudget_removesRecordGraph() throws {
        let repository = try makeRepository()
        let budget = makeBudget()
        try repository.saveBudget(budget)

        try repository.deleteBudget(id: budget.id)

        XCTAssertNil(try repository.fetchBudget(id: budget.id))
        XCTAssertTrue(try repository.fetchBudgets().isEmpty)
    }

    private func makeRepository() throws -> ImpBudgetRepository {
        let container = try FinanceRepositoryTestSupport.makeBudgetContainer()
        return ImpBudgetRepository(modelContext: ModelContext(container))
    }

    private func makeBudget(id: UUID = UUID(uuidString: "00000000-0000-0000-0000-000000000001")!, periodStart: Date = Date(timeIntervalSince1970: 0)) -> Budget {
        let budget = Budget(
            id: id,
            periodStart: periodStart,
            income: 1_000,
            method: .fiftyThirtyTwenty,
            createdAt: date(0)
        )
        budget.isLocked = true
        let allocation = BudgetAllocation(
            id: uuid(2),
            budget: budget,
            kind: .needs,
            ratio: 0.5,
            targetAmount: 500
        )
        let plan = FixedExpensePlan(
            id: uuid(3),
            budget: budget,
            allocation: allocation,
            name: "Rent",
            amount: 300,
            amountType: .fixed
        )
        let transaction = BudgetTransaction(
            id: uuid(4),
            budget: budget,
            allocation: allocation,
            type: .expense,
            title: "Rent paid",
            note: "September",
            occurredAt: date(50),
            amount: 300,
            paymentMethod: .banking
        )
        transaction.fixedExpensePlan = plan
        plan.transaction = transaction
        allocation.fixedExpensePlans = [plan]
        allocation.transactions = [transaction]
        budget.allocations = [allocation]
        budget.fixedExpensePlans = [plan]
        budget.transactions = [transaction]
        return budget
    }

    private func uuid(_ value: Int) -> UUID {
        UUID(uuidString: String(format: "00000000-0000-0000-0000-%012d", value))!
    }

    private func date(_ value: TimeInterval) -> Date {
        Date(timeIntervalSince1970: value)
    }
}
