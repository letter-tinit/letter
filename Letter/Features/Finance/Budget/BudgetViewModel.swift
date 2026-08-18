//
//  BudgetViewModel.swift
//  Personal Finance
//
//  Created by TiniT on 22/7/26.
//

import Foundation

@Observable
final class BudgetViewModel {
    private let repository: BudgetRepository
    private let balanceRepository: BalanceRepository
    var budgets: [Budget] = []
    var toastMessage: ToastMessage?

    init(repository: BudgetRepository, balanceRepository: BalanceRepository) {
        self.repository = repository
        self.balanceRepository = balanceRepository
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
    
    func lockBudget(_ budget: Budget) {
        do {
            try repository.lockBudget(budget)
            let amount = budget.carryoverAmount()
            if amount != .zero {
                try balanceRepository.addTransaction(
                    Transaction.makeBudgetCarryoverTransaction(amount)
                )
            }
            showInfo(String(format: "budget.locked.info".localized, budget.name))
        } catch {
            showError(error.localizedDescription)
        }
    }

    func deleteBudget(_ budget: Budget) {
        do {
            try repository.removeBudget(budget)
            budgets.removeAll { $0.id == budget.id }
            Haptic.warning()
        } catch {
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
    func showInfo(_ message: String) {
        toastMessage = ToastMessage(text: message, type: .info)
    }
    
    func showError(_ message: String) {
        toastMessage = ToastMessage(text: message, type: .failure)
    }
}
