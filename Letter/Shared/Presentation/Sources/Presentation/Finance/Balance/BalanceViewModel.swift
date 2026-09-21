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
    private var selectedMonth: FinanceMonth?
    
    public var isCreateNewBalancePresented: Bool = false
    public var toastMessage: ToastMessage?
    public var transactions: [Transaction] = []
    public var months: [BalanceMonth] = []
    public var balance = BalancePresentationModel()

    public init(useCase: any BalanceUseCase) {
        self.useCase = useCase
        load()
    }

    public func load() {
        do {
            let data = try useCase.load()
            transactions = data.transactions
            months = data.months
            syncBalancePresentation()
        } catch {
            showError(error.localizedDescription)
        }
    }

    public func selectMonth(_ month: FinanceMonth) {
        selectedMonth = month
        syncBalancePresentation()
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

    public func toggleSelectedMonthEditingLock() {
        guard let selectedMonth else { return }
        toggleEditingLock(
            for: selectedBalanceMonth
            ?? BalanceMonth(monthStart: selectedMonth.startDate)
        )
    }

    public func deleteTransactions(ids: Set<UUID>) {
        do {
            apply(try useCase.deleteTransactions(ids: ids))
        } catch {
            showError(error.localizedDescription)
        }
    }

    public func deleteSelectedMonthTransactions() {
        deleteTransactions(ids: Set(balance.transactions.map(\.id)))
    }
}

private extension BalanceViewModel {
    func apply(_ data: BalanceData) {
        transactions = data.transactions
        months = data.months
        syncBalancePresentation()
    }

    func showError(_ message: String) {
        toastMessage = ToastMessage(text: message, type: .failure)
    }

    func syncBalancePresentation() {
        guard let selectedMonth else {
            balance.transactions = []
            balance.isEditingUnlocked = true
            return
        }

        let selectedTransactions = transactions.filter {
            Calendar.current.isDate($0.occurredAt, equalTo: selectedMonth.startDate, toGranularity: .month)
        }
        let selectedBalanceMonth = months.first {
            Calendar.current.isDate($0.monthStart, equalTo: selectedMonth.startDate, toGranularity: .month)
        }

        balance.transactions = selectedTransactions.map(BalanceTransactionPresentationModel.init)
        balance.isEditingUnlocked = !(selectedBalanceMonth?.isLocked ?? false)
    }

    var selectedBalanceMonth: BalanceMonth? {
        guard let selectedMonth else { return nil }
        return months.first {
            Calendar.current.isDate($0.monthStart, equalTo: selectedMonth.startDate, toGranularity: .month)
        }
    }
    
}
