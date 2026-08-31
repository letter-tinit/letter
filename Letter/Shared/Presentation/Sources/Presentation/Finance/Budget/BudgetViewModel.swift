//
//  BudgetViewModel.swift
//  Letter
//
//  Created by TiniT on 22/7/26.
//

import Foundation
import Domain
import Utility
import Styleguide

@Observable
public final class BudgetViewModel {
    private let useCase: any BudgetUseCase
    public var budgets: [Budget] = []
    public var toastMessage: ToastMessage?

    public init(useCase: any BudgetUseCase) {
        self.useCase = useCase
        load()
    }

    public func load() {
        do {
            budgets = try useCase.fetchBudgets()
        } catch {
            showError("budget.storage.error.load".localized)
        }
    }

    public func createBudget(_ input: ValidatedBudgetInput, template: Budget?) {
        do {
            let budget = try useCase.createBudget(input, template: template)
            budgets.append(budget)
        } catch {
            showError("budget.create.error.save".localized)
        }
    }
    
    public func deleteBudget(_ budget: Budget) {
        let budgetID = budget.id
        budgets.removeAll { $0.id == budgetID }

        do {
            try useCase.deleteBudget(id: budgetID)
            Haptic.warning()
        } catch {
            load()
            showError("budget.storage.error.save".localized)
        }
    }

    public func toggleEditingLock(for budgetID: UUID) {
        do {
            apply(try useCase.toggleEditingLock(for: budgetID))
        } catch {
            showError("budget.storage.error.save".localized)
        }
    }

    public func addTransaction(
        _ input: ValidatedBudgetTransactionInput,
        to budgetID: UUID
    ) throws {
        try performMutation {
            try useCase.addTransaction(input, to: budgetID)
        }
    }

    public func updateTransaction(
        id transactionID: UUID,
        input: ValidatedBudgetTransactionInput,
        in budgetID: UUID
    ) throws {
        try performMutation {
            try useCase.updateTransaction(
                id: transactionID,
                input: input,
                in: budgetID
            )
        }
    }

    public func deleteTransaction(id transactionID: UUID, from budgetID: UUID) throws {
        try performMutation {
            try useCase.deleteTransaction(id: transactionID, from: budgetID)
        }
    }

    public func addFixedExpensePlan(
        _ input: ValidatedFixedExpensePlanInput,
        to budgetID: UUID
    ) throws {
        try performMutation {
            try useCase.addFixedExpensePlan(input, to: budgetID)
        }
    }

    public func updateFixedExpensePlan(
        id planID: UUID,
        input: ValidatedFixedExpensePlanInput,
        in budgetID: UUID
    ) throws {
        try performMutation {
            try useCase.updateFixedExpensePlan(
                id: planID,
                input: input,
                in: budgetID
            )
        }
    }

    public func deleteFixedExpensePlan(id planID: UUID, from budgetID: UUID) throws {
        try performMutation {
            try useCase.deleteFixedExpensePlan(id: planID, from: budgetID)
        }
    }

    public func completeFixedExpensePlan(
        id planID: UUID,
        input: ValidatedBudgetTransactionInput,
        in budgetID: UUID
    ) throws {
        try performMutation {
            try useCase.completeFixedExpensePlan(
                id: planID,
                input: input,
                in: budgetID
            )
        }
    }
}

private extension BudgetViewModel {
    func performMutation(_ action: () throws -> Budget) throws {
        do {
            apply(try action())
            toastMessage = nil
        } catch {
            showError(error.budgetMessage)
            throw error
        }
    }

    func apply(_ updatedBudget: Budget) {
        if let index = budgets.firstIndex(where: { $0.id == updatedBudget.id }) {
            budgets[index] = updatedBudget
        } else {
            budgets.append(updatedBudget)
            budgets.sort { $0.periodStart > $1.periodStart }
        }
    }

    func showError(_ message: String) {
        toastMessage = ToastMessage(text: message, type: .failure)
    }
}

private extension Error {
    var budgetMessage: String {
        guard let error = self as? BudgetError else {
            return "budget.storage.error.save".localized
        }

        let key = switch error {
        case .budgetNotFound: "budget.storage.error.load"
        case .invalidAmount: "transaction.form.error.amount.positive"
        case .invalidTransactionType: "transaction.form.error.description"
        case .allocationNotFound: "transaction.form.error.allocation"
        case .transactionNotFound: "transaction.form.error.delete"
        case .fixedExpensePlanNotFound: "fixed.plan.form.error.delete"
        case .fixedExpensePlanAlreadyCompleted: "fixed.plan.form.error.save"
        case .invalidFixedExpensePlanAmount: "fixed.plan.form.error.amount"
        case .unsupportedFixedExpensePlanAllocation: "fixed.plan.form.error.save"
        case .duplicatePeriod: "budget.create.error.duplicatePeriod"
        }
        return key.localized
    }
}
