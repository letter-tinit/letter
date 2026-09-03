import Foundation

@MainActor
public protocol BudgetUseCase {
    func fetchBudgets() throws -> [Budget]
    func createBudget(_ input: ValidatedBudgetInput, template: Budget?) throws -> Budget
    func deleteBudget(id: UUID) throws
    func toggleEditingLock(for budgetID: UUID) throws -> Budget
    func addTransaction(
        _ input: ValidatedBudgetTransactionInput,
        to budgetID: UUID
    ) throws -> Budget
    func updateTransaction(
        id transactionID: UUID,
        input: ValidatedBudgetTransactionInput,
        in budgetID: UUID
    ) throws -> Budget
    func deleteTransaction(id transactionID: UUID, from budgetID: UUID) throws -> Budget
    func addFixedExpensePlan(
        _ input: ValidatedFixedExpensePlanInput,
        to budgetID: UUID
    ) throws -> Budget
    func updateFixedExpensePlan(
        id planID: UUID,
        input: ValidatedFixedExpensePlanInput,
        in budgetID: UUID
    ) throws -> Budget
    func deleteFixedExpensePlan(id planID: UUID, from budgetID: UUID) throws -> Budget
    func completeFixedExpensePlan(
        id planID: UUID,
        input: ValidatedBudgetTransactionInput,
        in budgetID: UUID
    ) throws -> Budget
}

@MainActor
public final class ImpBudgetUseCase: BudgetUseCase {
    private let repository: any BudgetRepository

    public init(repository: any BudgetRepository) {
        self.repository = repository
    }

    public func fetchBudgets() throws -> [Budget] {
        try repository.fetchBudgets()
    }

    public func createBudget(_ input: ValidatedBudgetInput, template: Budget?) throws -> Budget {
        let budget = Budget.make(
            periodStart: input.periodStart,
            income: input.income,
            method: input.method,
            buckets: input.buckets
        )
        if input.reusesFixedExpensePlans, let template {
            budget.copyFixedExpensePlans(from: template)
        }
        try repository.saveBudget(budget)
        return budget
    }

    public func deleteBudget(id: UUID) throws {
        try repository.deleteBudget(id: id)
    }

    public func toggleEditingLock(for budgetID: UUID) throws -> Budget {
        let budget = try budget(id: budgetID)
        budget.isLocked.toggle()
        try repository.saveBudget(budget)
        return budget
    }

    public func addTransaction(
        _ input: ValidatedBudgetTransactionInput,
        to budgetID: UUID
    ) throws -> Budget {
        let budget = try budget(id: budgetID)
        let allocation = try allocation(id: input.allocationID, in: budget)
        guard input.amount > 0 else { throw BudgetError.invalidAmount }

        let transaction = makeTransaction(input, budget: budget, allocation: allocation)
        budget.transactions.append(transaction)
        allocation.transactions.append(transaction)
        try repository.saveBudget(budget)
        return budget
    }

    public func updateTransaction(
        id transactionID: UUID,
        input: ValidatedBudgetTransactionInput,
        in budgetID: UUID
    ) throws -> Budget {
        let budget = try budget(id: budgetID)
        guard let transaction = budget.transactions.first(where: { $0.id == transactionID }) else {
            throw BudgetError.transactionNotFound
        }
        guard input.amount > 0 else { throw BudgetError.invalidAmount }
        let allocation = try allocation(id: input.allocationID, in: budget)

        if let previous = transaction.allocation, previous.id != allocation.id {
            previous.transactions.removeAll { $0.id == transaction.id }
        }
        apply(input, budget: budget, allocation: allocation, to: transaction)
        if !allocation.transactions.contains(where: { $0.id == transaction.id }) {
            allocation.transactions.append(transaction)
        }

        if let plan = transaction.fixedExpensePlan {
            plan.name = input.description
            plan.amount = input.amount
        }
        try repository.saveBudget(budget)
        return budget
    }

    public func deleteTransaction(id transactionID: UUID, from budgetID: UUID) throws -> Budget {
        let budget = try budget(id: budgetID)
        guard let transaction = budget.transactions.first(where: { $0.id == transactionID }) else {
            throw BudgetError.transactionNotFound
        }
        budget.transactions.removeAll { $0.id == transaction.id }
        transaction.allocation?.transactions.removeAll { $0.id == transaction.id }
        transaction.fixedExpensePlan?.transaction = nil
        try repository.saveBudget(budget)
        return budget
    }

    public func addFixedExpensePlan(
        _ input: ValidatedFixedExpensePlanInput,
        to budgetID: UUID
    ) throws -> Budget {
        let budget = try budget(id: budgetID)
        guard let allocation = budget.allocations.first(where: { $0.kind.supportsFixedExpensePlan }) else {
            throw BudgetError.unsupportedFixedExpensePlanAllocation
        }
        guard input.amount >= 0 else { throw BudgetError.invalidFixedExpensePlanAmount }

        let plan = FixedExpensePlan(
            budget: budget,
            allocation: allocation,
            name: input.name,
            amount: input.amount,
            amountType: input.amountType
        )
        budget.fixedExpensePlans.append(plan)
        allocation.fixedExpensePlans.append(plan)
        try repository.saveBudget(budget)
        return budget
    }

    public func updateFixedExpensePlan(
        id planID: UUID,
        input: ValidatedFixedExpensePlanInput,
        in budgetID: UUID
    ) throws -> Budget {
        let budget = try budget(id: budgetID)
        let plan = try fixedExpensePlan(id: planID, in: budget)
        guard input.amount >= 0 else { throw BudgetError.invalidFixedExpensePlanAmount }

        plan.name = input.name
        plan.amount = input.amount
        plan.amountType = input.amountType
        plan.transaction?.title = input.name
        plan.transaction?.amount = input.amount
        try repository.saveBudget(budget)
        return budget
    }

    public func deleteFixedExpensePlan(id planID: UUID, from budgetID: UUID) throws -> Budget {
        let budget = try budget(id: budgetID)
        let plan = try fixedExpensePlan(id: planID, in: budget)
        budget.fixedExpensePlans.removeAll { $0.id == plan.id }
        plan.allocation?.fixedExpensePlans.removeAll { $0.id == plan.id }
        try repository.saveBudget(budget)
        return budget
    }

    public func completeFixedExpensePlan(
        id planID: UUID,
        input: ValidatedBudgetTransactionInput,
        in budgetID: UUID
    ) throws -> Budget {
        let budget = try budget(id: budgetID)
        let plan = try fixedExpensePlan(id: planID, in: budget)
        guard plan.transaction == nil else { throw BudgetError.fixedExpensePlanAlreadyCompleted }
        guard let allocation = plan.allocation else { throw BudgetError.allocationNotFound }
        guard input.amount > 0 else { throw BudgetError.invalidAmount }

        let transaction = makeTransaction(input, budget: budget, allocation: allocation)
        plan.name = input.description
        plan.amount = input.amount
        plan.transaction = transaction
        transaction.fixedExpensePlan = plan
        budget.transactions.append(transaction)
        allocation.transactions.append(transaction)
        try repository.saveBudget(budget)
        return budget
    }
}

private extension ImpBudgetUseCase {
    func budget(id: UUID) throws -> Budget {
        guard let budget = try repository.fetchBudget(id: id) else {
            throw BudgetError.budgetNotFound
        }
        return budget
    }

    func allocation(id: UUID, in budget: Budget) throws -> BudgetAllocation {
        guard let allocation = budget.allocations.first(where: { $0.id == id }) else {
            throw BudgetError.allocationNotFound
        }
        return allocation
    }

    func fixedExpensePlan(id: UUID, in budget: Budget) throws -> FixedExpensePlan {
        guard let plan = budget.fixedExpensePlans.first(where: { $0.id == id }) else {
            throw BudgetError.fixedExpensePlanNotFound
        }
        return plan
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
