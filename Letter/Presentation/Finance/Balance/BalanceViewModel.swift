//
//  BalanceViewModel.swift
//  Letter
//
//  Created by TiniT on 20/7/26.
//

import Foundation

@Observable
final class BalanceViewModel {
    private let useCase: any BalanceUseCase
    
    var isCreateNewBalancePresented: Bool = false
    var toastMessage: ToastMessage?
    var transactions: [Transaction] = []
    var months: [BalanceMonth] = []

    init(useCase: any BalanceUseCase) {
        self.useCase = useCase
        load()
    }

    func load() {
        do {
            let data = try useCase.load()
            transactions = data.transactions
            months = data.months
        } catch {
            showError(error.localizedDescription)
        }
    }
    
    func saveTransaction(_ input: TransactionInput, updating transaction: Transaction?) throws {
        try useCase.saveTransaction(input, updating: transaction)
        load()
    }
    
    func removeTransaction(_ transaction: Transaction) {
        do {
            try useCase.deleteTransaction(transaction)
            load()
            Haptic.warning()
        } catch {
            showError(error.localizedDescription)
        }
    }
    
    func toggleEditingLock(for month: BalanceMonth?, monthStart: Date) {
        do {
            try useCase.toggleEditingLock(for: month, monthStart: monthStart)
            load()
        } catch {
            showError(error.localizedDescription)
        }
    }

    func deleteTransactions(_ transactions: [Transaction]) {
        do {
            try useCase.deleteTransactions(transactions)
            load()
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
