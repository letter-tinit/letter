//
//  BudgetViewModel.swift
//  Letter
//
//  Created by TiniT on 22/7/26.
//

import Foundation

@Observable
final class BudgetViewModel {
    private let repository: BudgetRepository
    var budgets: [Budget] = []
    var toastMessage: ToastMessage?

    init(repository: BudgetRepository) {
        self.repository = repository
        load()
    }

    func load() {
        do {
            budgets = try repository.fetchBudgets()
        } catch {
            showError("budget.storage.error.load".localized)
        }
    }

    func createBudget(_ budget: Budget) {
        do {
            try repository.addBudget(budget)
            budgets.append(budget)
        } catch {
            showError("budget.create.error.save".localized)
        }
    }
    
    func deleteBudget(_ budget: Budget) {
        let budgetID = budget.id
        budgets.removeAll { $0.id == budgetID }

        do {
            try repository.removeBudget(budget)
            Haptic.warning()
        } catch {
            load()
            showError("budget.storage.error.save".localized)
        }
    }
    
    func save() {
        do {
            try repository.save()
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
