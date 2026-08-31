//
//  BalanceView.swift
//  Letter
//
//  Created by TiniT on 16/7/26.
//

import SwiftUI
import Domain
import Core
import Utility
import Styleguide

public struct BalanceView: View {
    @State private var viewModel: BalanceViewModel
    private let selectedMonth: FinanceMonth
    @State private var isDeleteConfirmationPresented = false
    private var isEditingUnlocked: Bool {
        !isEditingLocked
    }
    
    private var isEditingLocked: Bool {
        selectedBalanceMonth?.isLocked ?? false
    }
    
    private var transactions: [Domain.Transaction] {
        viewModel.transactions.filter {
            Calendar.current.isDate($0.occurredAt, equalTo: selectedMonth.startDate, toGranularity: .month)
        }
    }

    private var selectedBalanceMonth: BalanceMonth? {
        viewModel.months.first {
            Calendar.current.isDate($0.monthStart, equalTo: selectedMonth.startDate, toGranularity: .month)
        }
    }
    
    public var balance: Balance {
        Balance(transactions: transactions)
    }
    
    public init(_ viewModel: BalanceViewModel, selectedMonth: FinanceMonth) {
        self.viewModel = viewModel
        self.selectedMonth = selectedMonth
        
    }
    
    public var body: some View {
        BaseScreen {
            VStack {
                // MARK: - BALANCE VIEW
                if balance.transactionRows.isEmpty {
                    CommonEmptyView()
                } else {
                    BalanceCardView(balance: balance)
                        .padding(.horizontal)
                        .padding(.top)
                    
                    // MARK: - TRANSACTIONS
                    BalanceListView(
                        transactions: balance.transactionRows,
                        isEditingUnlocked: isEditingUnlocked
                    )
                    .environment(viewModel)
                }
            }
        }
        .navigationBarTitleDisplayMode(.automatic)
        .toolbar {
            if !transactions.isEmpty {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        Haptic.warning()
                        toggleEditingLock()
                    } label: {
                        Image(systemName: isEditingUnlocked ? "lock.open" : "lock")
                    }
                    .accessibilityLabel(isEditingUnlocked ? "networth.edit.lock".localized : "networth.edit.unlock".localized)
                }
                
                if isEditingUnlocked {
                    ToolbarItem(placement: .topBarLeading) {
                        Button(role: .destructive) {
                            Haptic.warning()
                            isDeleteConfirmationPresented = true
                        } label: {
                            Image(systemName: "trash")
                        }
                    }
                }
            }
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    Haptic.selection()
                    viewModel.isCreateNewBalancePresented = true
                } label: {
                    Image(systemName: "plus")
                }
                .disabled(!isEditingUnlocked)
            }
        }
        .sheet(isPresented: $viewModel.isCreateNewBalancePresented) {
            NavigationStack {
                BalanceFormView(onSave: viewModel.saveTransaction)
            }
        }
        .toast(message: viewModel.toastMessage)
        .deleteConfirmationDialog(
            isPresented: $isDeleteConfirmationPresented,
            title: "common.delete".localized,
            message: "common.delete.warning".localized
        ) {
            deleteMonthTransactions()
        }
    }
    
    private func toggleEditingLock() {
        viewModel.toggleEditingLock(
            for: selectedBalanceMonth ?? BalanceMonth(monthStart: selectedMonth.startDate)
        )
    }
    
    private func deleteMonthTransactions() {
        viewModel.deleteTransactions(ids: Set(transactions.map(\.id)))
    }
}
