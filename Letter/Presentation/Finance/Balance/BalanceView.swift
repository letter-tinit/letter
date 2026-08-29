//
//  BalanceView.swift
//  Letter
//
//  Created by TiniT on 16/7/26.
//

import SwiftUI
import SwiftData

struct BalanceView: View {
    @State private var viewModel: BalanceViewModel
    private let selectedMonth: FinanceMonth
    @State private var isDeleteConfirmationPresented = false
    @Query private var balanceMonths: [BalanceMonth]
    
    private var isEditingUnlocked: Bool {
        !isEditingLocked
    }
    
    private var isEditingLocked: Bool {
        balanceMonths.first?.isLocked ?? false
    }
    
    @Query
    private var transactions: [Transaction]
    
    var balance: Balance {
        Balance(transactions: transactions)
    }
    
    init(_ viewModel: BalanceViewModel, selectedMonth: FinanceMonth) {
        self.viewModel = viewModel
        self.selectedMonth = selectedMonth
        
        let start = selectedMonth.startDate
        let end = Calendar.current.date(byAdding: .month, value: 1, to: start)!
        let predicate = #Predicate<Transaction> {
            $0.occurredAt >= start && $0.occurredAt < end
        }
        _transactions = Query(
            filter: predicate,
            sort: [SortDescriptor(\.occurredAt, order: .reverse)]
        )
        let monthPredicate = #Predicate<BalanceMonth> {
            $0.monthStart == start
        }
        _balanceMonths = Query(filter: monthPredicate)
    }
    
    var body: some View {
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
            for: balanceMonths.first,
            monthStart: selectedMonth.startDate
        )
    }
    
    private func deleteMonthTransactions() {
        viewModel.deleteTransactions(transactions)
    }
}

#Preview {
    BalanceView(PreviewHelper.makeBalanceViewModel(), selectedMonth: FinanceMonth(.now))
        .modelContainer(
            PreviewContainer.shared.container
        )
}
