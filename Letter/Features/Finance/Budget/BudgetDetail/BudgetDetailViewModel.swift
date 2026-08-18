//
//  BudgetDetailViewModel.swift
//  Personal Finance
//
//  Created by TiniT on 22/7/26.
//

import Foundation

@Observable
final class BudgetDetailViewModel {
    let budget: Budget
    private let repository: BudgetRepository
    var toastMessage: ToastMessage?

    init(budget: Budget, repository: BudgetRepository) {
        self.budget = budget
        self.repository = repository
    }

    // MARK: - Transactions

    func addTransaction(_ input: ValidatedBudgetTransactionInput) {
        perform {
            guard let allocation = self.budget.allocations.first(where: { $0.id == input.allocationID }) else {
                throw BudgetError.allocationNotFound
            }
            guard input.amount > 0 else { throw BudgetError.invalidAmount }

            let transaction = BudgetTransaction(
                budget: self.budget,
                allocation: allocation,
                type: allocation.expectedTransactionType,
                title: input.description,
                note: input.note,
                occurredAt: input.occurredAt,
                amount: input.amount,
                paymentMethod: input.paymentMethod
            )
            self.budget.transactions.append(transaction)
        }
    }

    func updateTransaction(_ transaction: BudgetTransaction, input: ValidatedBudgetTransactionInput) {
        perform {
            guard input.amount > 0 else { throw BudgetError.invalidAmount }
            guard let allocation = self.budget.allocations.first(where: { $0.id == input.allocationID }) else {
                throw BudgetError.allocationNotFound
            }

            if let previousAllocation = transaction.allocation, previousAllocation.id != allocation.id {
                previousAllocation.transactions.removeAll { $0.id == transaction.id }
            }

            transaction.budget = self.budget
            transaction.allocation = allocation
            transaction.type = allocation.expectedTransactionType
            transaction.title = input.description
            transaction.note = input.note
            transaction.occurredAt = input.occurredAt
            transaction.amount = input.amount
            transaction.paymentMethod = input.paymentMethod

            if let fixedExpensePlan = transaction.fixedExpensePlan {
                fixedExpensePlan.name = input.description
                fixedExpensePlan.amount = input.amount
            }
        }
    }

    func deleteTransaction(_ transaction: BudgetTransaction) {
        perform {
            try self.repository.deleteTransaction(transaction)
        }
    }

    // MARK: - Fixed expense plans

    func addFixedExpensePlan(_ input: ValidatedFixedExpensePlanInput) {
        perform {
            guard let allocation = self.budget.allocations.first(where: { $0.kind.supportsFixedExpensePlan }) else {
                throw BudgetError.unsupportedFixedExpensePlanAllocation
            }
            guard input.amount >= 0 else { throw BudgetError.invalidFixedExpensePlanAmount }

            let plan = FixedExpensePlan(
                budget: self.budget,
                allocation: allocation,
                name: input.name,
                amount: input.amount,
                amountType: input.amountType
            )
            self.budget.fixedExpensePlans.append(plan)
        }
    }

    func updateFixedExpensePlan(_ plan: FixedExpensePlan, input: ValidatedFixedExpensePlanInput) {
        perform {
            guard input.amount >= 0 else { throw BudgetError.invalidFixedExpensePlanAmount }
            plan.name = input.name
            plan.amount = input.amount
            plan.amountType = input.amountType

            if let transaction = plan.transaction {
                transaction.title = input.name
                transaction.amount = input.amount
            }
        }
    }

    func deleteFixedExpensePlan(_ plan: FixedExpensePlan) {
        perform {
            try self.repository.deleteFixedExpensePlan(plan)
        }
    }

    func completeFixedExpensePlan(_ plan: FixedExpensePlan, input: ValidatedBudgetTransactionInput) {
        perform {
            guard plan.transaction == nil else {
                throw BudgetError.fixedExpensePlanAlreadyCompleted
            }
            guard let allocation = plan.allocation else {
                throw BudgetError.allocationNotFound
            }
            guard input.amount > 0 else { throw BudgetError.invalidAmount }

            let transaction = BudgetTransaction(
                budget: self.budget,
                allocation: allocation,
                type: allocation.expectedTransactionType,
                title: input.description,
                note: input.note,
                occurredAt: input.occurredAt,
                amount: input.amount,
                paymentMethod: input.paymentMethod
            )
            plan.name = input.description
            plan.amount = input.amount
            plan.transaction = transaction
            transaction.fixedExpensePlan = plan
            self.budget.transactions.append(transaction)
        }
    }
}

// MARK: - Private helper
private extension BudgetDetailViewModel {
    func perform(_ action: () throws -> Void) {
        do {
            try action()
            toastMessage = nil
            try repository.save()
        } catch {
            showError(error.localizedDescription)
        }
    }
    
    func showError(_ message: String) {
        toastMessage = ToastMessage(text: message, type: .failure)
    }
}
