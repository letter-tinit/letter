import Foundation

protocol BudgetDetailUseCase {
    func addTransaction(_ input: ValidatedBudgetTransactionInput, to budget: Budget) throws
    func updateTransaction(
        _ transaction: BudgetTransaction,
        input: ValidatedBudgetTransactionInput,
        in budget: Budget
    ) throws
    func deleteTransaction(_ transaction: BudgetTransaction) throws
    func addFixedExpensePlan(_ input: ValidatedFixedExpensePlanInput, to budget: Budget) throws
    func updateFixedExpensePlan(
        _ plan: FixedExpensePlan,
        input: ValidatedFixedExpensePlanInput
    ) throws
    func deleteFixedExpensePlan(_ plan: FixedExpensePlan) throws
    func completeFixedExpensePlan(
        _ plan: FixedExpensePlan,
        input: ValidatedBudgetTransactionInput,
        in budget: Budget
    ) throws
}

final class ImpBudgetDetailUseCase: BudgetDetailUseCase {
    private let repository: any BudgetRepository

    init(repository: any BudgetRepository) {
        self.repository = repository
    }

    func addTransaction(_ input: ValidatedBudgetTransactionInput, to budget: Budget) throws {
        let allocation = try allocation(id: input.allocationID, in: budget)
        guard input.amount > 0 else { throw BudgetError.invalidAmount }

        budget.transactions.append(makeTransaction(input, budget: budget, allocation: allocation))
        try repository.save()
    }

    func updateTransaction(
        _ transaction: BudgetTransaction,
        input: ValidatedBudgetTransactionInput,
        in budget: Budget
    ) throws {
        guard input.amount > 0 else { throw BudgetError.invalidAmount }
        let allocation = try allocation(id: input.allocationID, in: budget)

        if let previous = transaction.allocation, previous.id != allocation.id {
            previous.transactions.removeAll { $0.id == transaction.id }
        }
        apply(input, budget: budget, allocation: allocation, to: transaction)

        if let plan = transaction.fixedExpensePlan {
            plan.name = input.description
            plan.amount = input.amount
        }
        try repository.save()
    }

    func deleteTransaction(_ transaction: BudgetTransaction) throws {
        try repository.deleteTransaction(transaction)
    }

    func addFixedExpensePlan(_ input: ValidatedFixedExpensePlanInput, to budget: Budget) throws {
        guard let allocation = budget.allocations.first(where: { $0.kind.supportsFixedExpensePlan }) else {
            throw BudgetError.unsupportedFixedExpensePlanAllocation
        }
        guard input.amount >= 0 else { throw BudgetError.invalidFixedExpensePlanAmount }

        budget.fixedExpensePlans.append(FixedExpensePlan(
            budget: budget,
            allocation: allocation,
            name: input.name,
            amount: input.amount,
            amountType: input.amountType
        ))
        try repository.save()
    }

    func updateFixedExpensePlan(
        _ plan: FixedExpensePlan,
        input: ValidatedFixedExpensePlanInput
    ) throws {
        guard input.amount >= 0 else { throw BudgetError.invalidFixedExpensePlanAmount }
        plan.name = input.name
        plan.amount = input.amount
        plan.amountType = input.amountType
        plan.transaction?.title = input.name
        plan.transaction?.amount = input.amount
        try repository.save()
    }

    func deleteFixedExpensePlan(_ plan: FixedExpensePlan) throws {
        try repository.deleteFixedExpensePlan(plan)
    }

    func completeFixedExpensePlan(
        _ plan: FixedExpensePlan,
        input: ValidatedBudgetTransactionInput,
        in budget: Budget
    ) throws {
        guard plan.transaction == nil else { throw BudgetError.fixedExpensePlanAlreadyCompleted }
        guard let allocation = plan.allocation else { throw BudgetError.allocationNotFound }
        guard input.amount > 0 else { throw BudgetError.invalidAmount }

        let transaction = makeTransaction(input, budget: budget, allocation: allocation)
        plan.name = input.description
        plan.amount = input.amount
        plan.transaction = transaction
        transaction.fixedExpensePlan = plan
        budget.transactions.append(transaction)
        try repository.save()
    }
}

private extension ImpBudgetDetailUseCase {
    func allocation(id: UUID, in budget: Budget) throws -> BudgetAllocation {
        guard let allocation = budget.allocations.first(where: { $0.id == id }) else {
            throw BudgetError.allocationNotFound
        }
        return allocation
    }

    func makeTransaction(
        _ input: ValidatedBudgetTransactionInput,
        budget: Budget,
        allocation: BudgetAllocation
    ) -> BudgetTransaction {
        BudgetTransaction(
            budget: budget,
            allocation: allocation,
            type: allocation.expectedTransactionType,
            title: input.description,
            note: input.note,
            occurredAt: input.occurredAt,
            amount: input.amount,
            paymentMethod: input.paymentMethod
        )
    }

    func apply(
        _ input: ValidatedBudgetTransactionInput,
        budget: Budget,
        allocation: BudgetAllocation,
        to transaction: BudgetTransaction
    ) {
        transaction.budget = budget
        transaction.allocation = allocation
        transaction.type = allocation.expectedTransactionType
        transaction.title = input.description
        transaction.note = input.note
        transaction.occurredAt = input.occurredAt
        transaction.amount = input.amount
        transaction.paymentMethod = input.paymentMethod
    }
}
