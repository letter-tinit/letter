protocol BudgetUseCase {
    func fetchBudgets() throws -> [Budget]
    func createBudget(_ input: ValidatedBudgetInput, template: Budget?) throws -> Budget
    func deleteBudget(_ budget: Budget) throws
    func toggleEditingLock(for budget: Budget) throws
}

final class ImpBudgetUseCase: BudgetUseCase {
    private let repository: any BudgetRepository

    init(repository: any BudgetRepository) {
        self.repository = repository
    }

    func fetchBudgets() throws -> [Budget] {
        try repository.fetchBudgets()
    }

    func createBudget(_ input: ValidatedBudgetInput, template: Budget?) throws -> Budget {
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

    func deleteBudget(_ budget: Budget) throws {
        try repository.deleteBudget(id: budget.id)
    }

    func toggleEditingLock(for budget: Budget) throws {
        budget.isLocked.toggle()
        try repository.saveBudget(budget)
    }
}
