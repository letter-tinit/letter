//
//  BalanceViewModel.swift
//  Letter
//
//  Created by TiniT on 20/7/26.
//

import Foundation
import Domain
import Utility
import Styleguide

@Observable
@MainActor
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
    
    public func saveTransaction(_ transaction: Transaction) throws {
        apply(try useCase.saveTransaction(transaction))
    }
    
    public func removeTransaction(id: UUID) {
        do {
            apply(try useCase.deleteTransaction(id: id))
            Haptic.warning()
        } catch {
            showError(error.localizedDescription)
        }
    }
    
    public func toggleEditingLock(for month: BalanceMonth) {
        do {
            apply(try useCase.toggleEditingLock(for: month))
        } catch {
            showError(error.localizedDescription)
        }
    }

    public func deleteTransactions(ids: Set<UUID>) {
        do {
            apply(try useCase.deleteTransactions(ids: ids))
        } catch {
            showError(error.localizedDescription)
        }
    }
}

private extension BalanceViewModel {
    func apply(_ data: BalanceData) {
        transactions = data.transactions
        months = data.months
    }

    func showError(_ message: String) {
        toastMessage = ToastMessage(text: message, type: .failure)
    }
    
}
