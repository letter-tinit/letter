import Foundation

@Observable
final class BudgetDetailViewModel {
    private(set) var budget: Budget
    private let useCase: any BudgetDetailUseCase
    var toastMessage: ToastMessage?

    init(budget: Budget, useCase: any BudgetDetailUseCase) {
        self.budget = budget
        self.useCase = useCase
    }

    func addTransaction(_ input: ValidatedBudgetTransactionInput) {
        perform { try useCase.addTransaction(input, to: budget) }
    }

    func updateTransaction(
        _ transaction: BudgetTransaction,
        input: ValidatedBudgetTransactionInput
    ) {
        perform { try useCase.updateTransaction(transaction, input: input, in: budget) }
    }

    func deleteTransaction(_ transaction: BudgetTransaction) {
        perform { try useCase.deleteTransaction(transaction, from: budget) }
    }

    func addFixedExpensePlan(_ input: ValidatedFixedExpensePlanInput) {
        perform { try useCase.addFixedExpensePlan(input, to: budget) }
    }

    func updateFixedExpensePlan(
        _ plan: FixedExpensePlan,
        input: ValidatedFixedExpensePlanInput
    ) {
        perform { try useCase.updateFixedExpensePlan(plan, input: input) }
    }

    func deleteFixedExpensePlan(_ plan: FixedExpensePlan) {
        perform { try useCase.deleteFixedExpensePlan(plan, from: budget) }
    }

    func completeFixedExpensePlan(
        _ plan: FixedExpensePlan,
        input: ValidatedBudgetTransactionInput
    ) {
        perform { try useCase.completeFixedExpensePlan(plan, input: input, in: budget) }
    }

    private func perform(_ action: () throws -> Void) {
        do {
            try action()
            budget = budget
            toastMessage = nil
        } catch {
            toastMessage = ToastMessage(text: error.localizedDescription, type: .failure)
        }
    }
}
