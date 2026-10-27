//
//  BudgetViewModel.swift
//  Presentation
//
//  Created by Tín Nguyễn on 15/10/26.
//

import Domain
import Foundation
import Observation
import Styleguide

@Observable
public final class BudgetViewModel {
    private let useCase: any BudgetUseCase
    private var selectedMonth: FinanceMonth?
    
    // MARK: - Property
    public var budget: BudgetPresentationModel?
    public private(set) var financeMonths: Set<FinanceMonth> = []
    public var toastMessage: ToastMessage?
    // Temporary
    public var budgetInputFormState = BudgetInputFormState()
    public var budgetTransactionInputFormState = BudgetTransactionInputFormState()
    public var transactionPendingDeletionID: UUID?
    public var transactionPendingEditingID: UUID?
    // Presenting
    public var budgetInputFormPresenting = false
    public var transactionInputFormPresenting = false
    public var budgetDeleteConfirmation = false
    public var transactionDeleteConfirmation = false
    
    // MARK: - INIT
    public init(useCase: any BudgetUseCase) {
        self.useCase = useCase
    }
}

// MARK: - BUDGET SCREEN PUBLIC API
public extension BudgetViewModel {
    func selectedMonth(_ selectedMonth: FinanceMonth) {
        self.selectedMonth = selectedMonth
    }

    func loadFinanceMonths() {
        do {
            financeMonths = try useCase.budgetMonths()
        } catch {
            showError(error.localizedDescription)
        }
    }
    
    func load() {
        guard let date = selectedMonth?.startDate else { return }
        
        do {
            if let domain = try useCase.load(date) {
                budget = BudgetPresentationModel(domain: domain)
            } else {
                budget = nil
            }
        } catch {
            showError(error.localizedDescription)
        }
    }
    
    func didTapLockButton() {
        toggleBudgetLock()
    }
    
    func didTapCreateNewBudget() {
        budgetInputFormPresenting = true
        hapticImpac()
    }
    
    func didTapCreateNewTransaction() {
        hapticImpac()
        budgetTransactionInputFormState.reset()
        transactionPendingEditingID = nil
        transactionInputFormPresenting = true
    }
    
    func didTapDeleteBudgetButton() {
        hapticImpac()
        budgetDeleteConfirmation = true
    }
    
    func didConfirmDeleteBudget() {
        deleteBudget()
    }
    
    func didTapDeleteTransactionButton(transactionId: UUID) {
        transactionDeleteConfirmation = true
        transactionPendingDeletionID = transactionId
    }
    
    func didCancelDeleteTransaction() {
        transactionPendingDeletionID = nil
    }
    
    func didConfirmDeleteTransaction() {
        deleteTransaction()
    }
    
    func didTapOnTransactionItem(transaction: BudgetTransactionPresentationModel) {
        transactionInputFormPresenting = true
        transactionPendingEditingID = transaction.id
        budgetTransactionInputFormState.mapFromPresentationModel(transaction: transaction)
    }
}

// MARK: - BUDGET INPUT FORM PUBLIC API
public extension BudgetViewModel {
    func didTapSubmitBudgetCreationForm() {
        createBudget()
    }
}

// MARK: - BUDGET TRANSACTION INPUT FORM PUBLIC API
public extension BudgetViewModel {
    func transactionInputTitle() -> String {
        return String(
            format: transactionPendingEditingID != nil ? "common.edit".localized : "common.create".localized,
            "common.transaction".localized
        )
    }
    
    func didTapSaveTransaction() {
        do {
            try budgetTransactionInputFormState.validate()
            if let transactionPendingEditingID {
                updateTransaction(transactionID: transactionPendingEditingID)
            } else {
                createTransaction()
            }
        } catch {
            showError(error.localizedDescription)
        }
    }
}

// MARK: - CRUD BUDGET
private extension BudgetViewModel {
    func toggleBudgetLock() {
        guard let budget else { return }
        
        do {
            try useCase.toggleBudgetLock(budget.id)
            onChangeData()
        } catch {
            showError(error.localizedDescription)
        }
    }
    
    func createBudget() {
        do {
            try budgetInputFormState.validate()
            
            guard let month = selectedMonth?.startDate else {
                showError("Unable to determine the budget month.")
                return
            }
            
            let newBudget = Budget(
                id: UUID(),
                month: month,
                isLocked: false,
                incomeAmount: budgetInputFormState.incomeAmountValue,
                pyfAmount: budgetInputFormState.pyfAmountValue,
                transactions: []
            )
            
            try useCase.create(newBudget)
            
            budget = BudgetPresentationModel(domain: newBudget)
            loadFinanceMonths()
            budgetInputFormState.reset()
            budgetInputFormPresenting = false
            
            hapticImpac()
        } catch {
            showError(error.localizedDescription)
        }
    }
    
    func deleteBudget() {
        guard let budgetId = budget?.id else { return }
        
        do {
            try useCase.delete(budgetId)
            onChangeData()
        } catch {
            showError(error.localizedDescription)
        }
    }
    
    func createTransaction() {
        let transaction = BudgetTransaction(
            id: UUID(),
            amount: budgetTransactionInputFormState.amount.toDecimal(),
            description: budgetTransactionInputFormState.description,
            date: budgetTransactionInputFormState.date,
            category: budgetTransactionInputFormState.category
        )
        
        guard
            let budget else {
            return
        }
        
        do {
            try useCase.createTransaction(transaction, to: budget.id)
            onChangeData()
        } catch {
            showError(error.localizedDescription)
        }
    }
    
    func updateTransaction(transactionID: UUID) {
        guard let budgetId = budget?.id else { return }
        
        let transaction = BudgetTransaction(
            id: transactionID,
            amount: budgetTransactionInputFormState.amount.toDecimal(),
            description: budgetTransactionInputFormState.description,
            date: budgetTransactionInputFormState.date,
            category: budgetTransactionInputFormState.category
        )
        
        do {
            try useCase.updateTransaction(transaction, to: budgetId)
            transactionPendingEditingID = nil
            onChangeData()
        } catch {
            showError(error.localizedDescription)
        }
    }
    
    func deleteTransaction() {
        guard
            let budget,
            let transactionID = transactionPendingDeletionID
                else {
            return
        }
        
        do {
            try useCase.deleteTransaction(transactionID, to: budget.id)
            transactionPendingDeletionID = nil
            onChangeData()
        } catch {
            showError(error.localizedDescription)
        }
    }
}

// MARK: - HELPER
private extension BudgetViewModel {
    func showError(_ message: String) {
        toastMessage = ToastMessage(text: message, type: .failure)
    }
    
    func onChangeData() {
        load()
        loadFinanceMonths()
        hapticImpac()
    }
    
    func hapticImpac() {
        Haptic.impact()
    }
}
