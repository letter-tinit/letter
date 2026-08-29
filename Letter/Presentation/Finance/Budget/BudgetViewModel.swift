//
//  BudgetViewModel.swift
//  Letter
//
//  Created by TiniT on 22/7/26.
//

import Foundation

@Observable
final class BudgetViewModel {
    private let useCase: any BudgetUseCase
    var budgets: [Budget] = []
    var toastMessage: ToastMessage?

    init(useCase: any BudgetUseCase) {
        self.useCase = useCase
        load()
    }

    func load() {
        do {
            budgets = try useCase.fetchBudgets()
        } catch {
            showError("budget.storage.error.load".localized)
        }
    }

    func createBudget(_ input: ValidatedBudgetInput, template: Budget?) {
        do {
            let budget = try useCase.createBudget(input, template: template)
            budgets.append(budget)
        } catch {
            showError("budget.create.error.save".localized)
        }
    }
    
    func deleteBudget(_ budget: Budget) {
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

    func toggleEditingLock(for budget: Budget) {
        do {
            try useCase.toggleEditingLock(for: budget)
        } catch {
            showError("budget.storage.error.save".localized)
        }
    }
    
    func save() {
        do {
            try useCase.save()
        }
        catch {
            showError("budget.storage.error.save".localized)
        }
    }
}

private extension BudgetViewModel {
    func showError(_ message: String) {
        toastMessage = ToastMessage(text: message, type: .failure)
    }
}
