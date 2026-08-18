//
//  BalanceViewModel.swift
//  Letter
//
//  Created by TiniT on 20/7/26.
//

import Foundation

@Observable
final class BalanceViewModel {
    private let repository: BalanceRepository
    
    var isCreateNewBalancePresented: Bool = false
    var toastMessage: ToastMessage?

    init(repository: BalanceRepository) {
        self.repository = repository
    }
    
    func addTransaction(_ transaction: Transaction) {
        do {
            try repository.addTransaction(transaction)
        } catch {
            showError(error.localizedDescription)
        }
    }
    
    func removeTransaction(_ transaction: Transaction) {
        do {
            try repository.deleteTransaction(transaction)
            Haptic.warning()
        } catch {
            showError(error.localizedDescription)
        }
    }
    
    func updateTransaction(_ transaction: Transaction) {
        do {
            try repository.updateTransaction(transaction)
        } catch {
            showError(error.localizedDescription)
        }
    }
}

private extension BalanceViewModel {
    func showError(_ message: String) {
        toastMessage = ToastMessage(text: message, type: .failure)
    }
    
}
