//
//  BudgetViewModel.swift
//  Letter
//
//  Created by TiniT on 22/7/26.
//

import Foundation
import Domain
import Core
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
            try useCase.deleteBudget(budget)
            Haptic.warning()
        } catch {
            load()
            showError("budget.storage.error.save".localized)
        }
    }

    public func toggleEditingLock(for budget: Budget) {
        do {
            try useCase.toggleEditingLock(for: budget)
            load()
        } catch {
            showError("budget.storage.error.save".localized)
        }
    }
    
}

private extension BudgetViewModel {
    public func showError(_ message: String) {
        toastMessage = ToastMessage(text: message, type: .failure)
    }
}
