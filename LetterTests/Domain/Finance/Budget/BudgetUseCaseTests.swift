import Foundation
import XCTest
@testable import Domain

@MainActor
final class BudgetUseCaseTests: XCTestCase {
    func test_fetchBudgets_returnsRepositoryBudgets() throws {
        let budget = makeBudget()
        let repository = FakeBudgetRepository(budgets: [budget])
        let useCase = ImpBudgetUseCase(repository: repository)

        let budgets = try useCase.fetchBudgets()

        XCTAssertEqual(budgets, [budget])
    }

    func test_createBudget_savesGeneratedBudget() throws {
        let repository = FakeBudgetRepository()
        let useCase = ImpBudgetUseCase(repository: repository)
        let input = ValidatedBudgetInput(
            periodStart: Date(timeIntervalSince1970: 2_678_400),
            income: 1000,
            method: .fiftyThirtyTwenty,
            buckets: [
                BudgetBucket(kind: .needs, ratio: 0.5, amount: 500),
                BudgetBucket(kind: .wants, ratio: 0.3, amount: 300),
                BudgetBucket(kind: .savings, ratio: 0.2, amount: 200)
            ],
            reusesFixedExpensePlans: false
        )

        let budget = try useCase.createBudget(input, template: nil)

        XCTAssertEqual(repository.savedBudgets, [budget])
        XCTAssertEqual(budget.income, 1000)
        XCTAssertEqual(budget.allocations.map(\.kind), [.needs, .wants, .savings])
    }

    func test_createBudget_reusesFixedExpensePlansFromTemplate() throws {
        let template = makeBudget()
        let sourceAllocation = template.allocations[0]
        let plan = FixedExpensePlan(
            budget: template,
            allocation: sourceAllocation,
            name: "Rent",
            amount: 300,
            amountType: .fixed
        )
        template.fixedExpensePlans.append(plan)
        sourceAllocation.fixedExpensePlans.append(plan)
        let repository = FakeBudgetRepository()
        let useCase = ImpBudgetUseCase(repository: repository)

        let budget = try useCase.createBudget(
            ValidatedBudgetInput(
                periodStart: Date(timeIntervalSince1970: 0),
                income: 1000,
                method: .fiftyThirtyTwenty,
                buckets: [
                    BudgetBucket(kind: .needs, ratio: 0.5, amount: 500),
                    BudgetBucket(kind: .wants, ratio: 0.3, amount: 300),
                    BudgetBucket(kind: .savings, ratio: 0.2, amount: 200)
                ],
                reusesFixedExpensePlans: true
            ),
            template: template
        )

        XCTAssertEqual(budget.fixedExpensePlans.count, 1)
        XCTAssertEqual(budget.fixedExpensePlans[0].name, "Rent")
        XCTAssertEqual(budget.fixedExpensePlans[0].amount, 300)
        XCTAssertNotEqual(budget.fixedExpensePlans[0].id, plan.id)
    }

    func test_toggleEditingLock_flipsAndSavesBudget() throws {
        let budget = makeBudget()
        let repository = FakeBudgetRepository(budgets: [budget])
        let useCase = ImpBudgetUseCase(repository: repository)

        let updated = try useCase.toggleEditingLock(for: budget.id)

        XCTAssertTrue(updated.isLocked)
        XCTAssertEqual(repository.savedBudgets, [budget])
    }

    func test_addTransaction_addsExpenseToAllocationAndBudget() throws {
        let budget = makeBudget()
        let allocation = budget.allocations[0]
        let repository = FakeBudgetRepository(budgets: [budget])
        let useCase = ImpBudgetUseCase(repository: repository)

        let updated = try useCase.addTransaction(
            makeTransactionInput(allocationID: allocation.id, amount: 45),
            to: budget.id
        )

        XCTAssertEqual(updated.transactions.count, 1)
        XCTAssertEqual(allocation.transactions, updated.transactions)
        XCTAssertEqual(updated.transactions[0].type, .expense)
        XCTAssertEqual(updated.transactions[0].amount, 45)
    }

    func test_addTransaction_throwsInvalidAmountWhenAmountIsNotPositive() throws {
        let budget = makeBudget()
        let repository = FakeBudgetRepository(budgets: [budget])
        let useCase = ImpBudgetUseCase(repository: repository)

        XCTAssertThrowsError(
            try useCase.addTransaction(
                makeTransactionInput(allocationID: budget.allocations[0].id, amount: 0),
                to: budget.id
            )
        ) { error in
            XCTAssertEqual(error as? BudgetError, .invalidAmount)
        }
    }

    func test_updateTransaction_movesTransactionBetweenAllocations() throws {
        let budget = makeBudget()
        let sourceAllocation = budget.allocations[0]
        let destinationAllocation = budget.allocations[1]
        let transaction = BudgetTransaction(
            budget: budget,
            allocation: sourceAllocation,
            type: .expense,
            title: "Old",
            amount: 10,
            paymentMethod: .cash
        )
        budget.transactions.append(transaction)
        sourceAllocation.transactions.append(transaction)
        let repository = FakeBudgetRepository(budgets: [budget])
        let useCase = ImpBudgetUseCase(repository: repository)

        let updated = try useCase.updateTransaction(
            id: transaction.id,
            input: makeTransactionInput(
                allocationID: destinationAllocation.id,
                description: "New",
                amount: 20
            ),
            in: budget.id
        )

        XCTAssertEqual(updated.transactions[0].title, "New")
        XCTAssertEqual(updated.transactions[0].amount, 20)
        XCTAssertTrue(sourceAllocation.transactions.isEmpty)
        XCTAssertEqual(destinationAllocation.transactions, [transaction])
    }

    func test_deleteTransaction_removesTransactionFromBudgetAndAllocation() throws {
        let budget = makeBudget()
        let allocation = budget.allocations[0]
        let transaction = BudgetTransaction(
            budget: budget,
            allocation: allocation,
            type: .expense,
            title: "Lunch",
            amount: 12,
            paymentMethod: .cash
        )
        budget.transactions.append(transaction)
        allocation.transactions.append(transaction)
        let repository = FakeBudgetRepository(budgets: [budget])
        let useCase = ImpBudgetUseCase(repository: repository)

        let updated = try useCase.deleteTransaction(id: transaction.id, from: budget.id)

        XCTAssertTrue(updated.transactions.isEmpty)
        XCTAssertTrue(allocation.transactions.isEmpty)
    }

    func test_addFixedExpensePlan_addsPlanToSupportedAllocation() throws {
        let budget = makeBudget()
        let allocation = budget.allocations[0]
        let repository = FakeBudgetRepository(budgets: [budget])
        let useCase = ImpBudgetUseCase(repository: repository)

        let updated = try useCase.addFixedExpensePlan(
            ValidatedFixedExpensePlanInput(name: "Rent", amount: 350, amountType: .fixed),
            to: budget.id
        )

        XCTAssertEqual(updated.fixedExpensePlans.count, 1)
        XCTAssertEqual(allocation.fixedExpensePlans, updated.fixedExpensePlans)
        XCTAssertEqual(updated.fixedExpensePlans[0].name, "Rent")
    }

    func test_completeFixedExpensePlan_createsLinkedTransaction() throws {
        let budget = makeBudget()
        let allocation = budget.allocations[0]
        let plan = FixedExpensePlan(
            budget: budget,
            allocation: allocation,
            name: "Rent",
            amount: 350,
            amountType: .fixed
        )
        budget.fixedExpensePlans.append(plan)
        allocation.fixedExpensePlans.append(plan)
        let repository = FakeBudgetRepository(budgets: [budget])
        let useCase = ImpBudgetUseCase(repository: repository)

        let updated = try useCase.completeFixedExpensePlan(
            id: plan.id,
            input: makeTransactionInput(allocationID: allocation.id, description: "Rent Paid", amount: 350),
            in: budget.id
        )

        XCTAssertEqual(updated.transactions.count, 1)
        XCTAssertEqual(plan.transaction, updated.transactions[0])
        XCTAssertEqual(updated.transactions[0].fixedExpensePlan, plan)
        XCTAssertEqual(plan.name, "Rent Paid")
    }

    func test_completeFixedExpensePlan_throwsWhenAlreadyCompleted() throws {
        let budget = makeBudget()
        let allocation = budget.allocations[0]
        let plan = FixedExpensePlan(budget: budget, allocation: allocation, name: "Rent", amount: 350)
        let transaction = BudgetTransaction(
            budget: budget,
            allocation: allocation,
            type: .expense,
            title: "Rent",
            amount: 350,
            paymentMethod: .cash
        )
        plan.transaction = transaction
        budget.fixedExpensePlans.append(plan)
        let repository = FakeBudgetRepository(budgets: [budget])
        let useCase = ImpBudgetUseCase(repository: repository)

        XCTAssertThrowsError(
            try useCase.completeFixedExpensePlan(
                id: plan.id,
                input: makeTransactionInput(allocationID: allocation.id, amount: 350),
                in: budget.id
            )
        ) { error in
            XCTAssertEqual(error as? BudgetError, .fixedExpensePlanAlreadyCompleted)
        }
    }
}

private func makeBudget(id: UUID = UUID()) -> Budget {
    Budget.make(
        periodStart: Date(timeIntervalSince1970: 0),
        income: 1000,
        method: .fiftyThirtyTwenty,
        buckets: [
            BudgetBucket(kind: .needs, ratio: 0.5, amount: 500),
            BudgetBucket(kind: .wants, ratio: 0.3, amount: 300),
            BudgetBucket(kind: .savings, ratio: 0.2, amount: 200)
        ]
    ).settingID(id)
}

private func makeTransactionInput(
    allocationID: UUID,
    description: String = "Lunch",
    amount: Decimal
) -> ValidatedBudgetTransactionInput {
    ValidatedBudgetTransactionInput(
        description: description,
        allocationID: allocationID,
        amount: amount,
        occurredAt: Date(timeIntervalSince1970: 0),
        paymentMethod: .cash,
        note: "Note"
    )
}

private extension Budget {
    func settingID(_ id: UUID) -> Budget {
        self.id = id
        return self
    }
}

@MainActor
private final class FakeBudgetRepository: BudgetRepository {
    var budgets: [Budget]
    var savedBudgets: [Budget] = []
    var deletedBudgetIDs: [UUID] = []

    init(budgets: [Budget] = []) {
        self.budgets = budgets
    }

    func fetchBudgets() throws -> [Budget] {
        budgets
    }

    func fetchBudget(id: UUID) throws -> Budget? {
        budgets.first { $0.id == id }
    }

    func saveBudget(_ budget: Budget) throws {
        savedBudgets.append(budget)
        budgets.removeAll { $0.id == budget.id }
        budgets.append(budget)
    }

    func deleteBudget(id: UUID) throws {
        deletedBudgetIDs.append(id)
        budgets.removeAll { $0.id == id }
    }
}
