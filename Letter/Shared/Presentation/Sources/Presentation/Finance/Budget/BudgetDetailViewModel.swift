import Foundation
import Domain
import Core
import Utility
import Styleguide

@Observable
public final class BudgetDetailViewModel {
    private(set) var budget: Budget
    private let useCase: any BudgetDetailUseCase
    public var toastMessage: ToastMessage?

    public init(budget: Budget, useCase: any BudgetDetailUseCase) {
        self.budget = budget
        self.useCase = useCase
    }

    public func addTransaction(_ input: ValidatedBudgetTransactionInput) {
        perform { try useCase.addTransaction(input, to: budget) }
    }

    public func updateTransaction(
        _ transaction: BudgetTransaction,
        input: ValidatedBudgetTransactionInput
    ) {
        perform { try useCase.updateTransaction(transaction, input: input, in: budget) }
    }

    public func deleteTransaction(_ transaction: BudgetTransaction) {
        perform { try useCase.deleteTransaction(transaction, from: budget) }
    }

    public func addFixedExpensePlan(_ input: ValidatedFixedExpensePlanInput) {
        perform { try useCase.addFixedExpensePlan(input, to: budget) }
    }

    public func updateFixedExpensePlan(
        _ plan: FixedExpensePlan,
        input: ValidatedFixedExpensePlanInput
    ) {
        perform { try useCase.updateFixedExpensePlan(plan, input: input) }
    }

    public func deleteFixedExpensePlan(_ plan: FixedExpensePlan) {
        perform { try useCase.deleteFixedExpensePlan(plan, from: budget) }
    }

    public func completeFixedExpensePlan(
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
