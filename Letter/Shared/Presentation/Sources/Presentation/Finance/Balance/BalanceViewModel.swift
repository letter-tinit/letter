//
//  BalanceViewModel.swift
//  Letter
//
//  Created by TiniT on 20/7/26.
//

import Foundation
import Domain
import Core
import Utility
import Styleguide

@Observable
public final class BalanceViewModel {
    private let useCase: any BalanceUseCase
    
    public var isCreateNewBalancePresented: Bool = false
    public var toastMessage: ToastMessage?
    public var transactions: [Transaction] = []
    public var months: [BalanceMonth] = []

    public init(useCase: any BalanceUseCase) {
        self.useCase = useCase
        load()
    }

    public func load() {
        do {
            let data = try useCase.load()
            transactions = data.transactions
            months = data.months
        } catch {
            showError(error.localizedDescription)
        }
    }
    
    public func saveTransaction(_ input: TransactionInput, updating transaction: Transaction?) throws {
        try useCase.saveTransaction(input, updating: transaction)
        load()
    }
    
    public func removeTransaction(_ transaction: Transaction) {
        do {
            try useCase.deleteTransaction(transaction)
            load()
            Haptic.warning()
        } catch {
            showError(error.localizedDescription)
        }
    }
    
    public func toggleEditingLock(for month: BalanceMonth?, monthStart: Date) {
        do {
            try useCase.toggleEditingLock(for: month, monthStart: monthStart)
            load()
        } catch {
            showError(error.localizedDescription)
        }
    }

    public func deleteTransactions(_ transactions: [Transaction]) {
        do {
            try useCase.deleteTransactions(transactions)
            load()
        } catch {
            showError(error.localizedDescription)
        }
    }
}

private extension BalanceViewModel {
    public func showError(_ message: String) {
        toastMessage = ToastMessage(text: message, type: .failure)
    }
    
}
