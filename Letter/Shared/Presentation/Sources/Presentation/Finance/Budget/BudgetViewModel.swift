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
    
    public var budget: BudgetPresentationModel?
    public var toastMessage: ToastMessage?
    public var transactionPendingDeletionID: UUID?
    
    public init(useCase: any BudgetUseCase) {
        self.useCase = useCase
    }
    
    public func selectedMonth(_ selectedMonth: FinanceMonth) {
        self.selectedMonth = selectedMonth
    }
    
    public func load() {
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
    
    public func createTransaction() {
        let transaction = BudgetTransactionPresentationModel(id: UUID(), amount: 1000, description: "AHIIH", date: Date(), category: .bills).domain
        guard let budget else { return }
        do {
            try useCase.createTransaction(transaction, to: budget.id)
            onChangeData()
        } catch {
            showError(error.localizedDescription)
        }
    }
    
    public func deleteTransaction() {
        guard let budget, let transactionPendingDeletionID else { return }
        do {
            try useCase.deleteTransaction(transactionPendingDeletionID, to: budget.id)
            onChangeData()
        } catch {
            showError(error.localizedDescription)
        }
    }
}

private extension BudgetViewModel {
    func showError(_ message: String) {
        toastMessage = ToastMessage(text: message, type: .failure)
    }
    
    func onChangeData() {
        load()
        Haptic.impact()
    }
}
