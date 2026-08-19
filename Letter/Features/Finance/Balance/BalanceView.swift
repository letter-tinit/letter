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
    @Environment(\.modelContext) private var modelContext
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
            ToolbarItem(placement: .topBarLeading) {
                Button {
                    toggleEditingLock()
                } label: {
                    Image(systemName: isEditingUnlocked ? "lock.open" : "lock")
                }
                .accessibilityLabel(isEditingUnlocked ? "networth.edit.lock".localized : "networth.edit.unlock".localized)
            }
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    viewModel.isCreateNewBalancePresented = true
                } label: {
                    Image(systemName: "plus")
                }
                .disabled(!isEditingUnlocked)
            }
        }
        .sheet(isPresented: $viewModel.isCreateNewBalancePresented) {
            NavigationStack {
                BalanceFormView(onSave: viewModel.addTransaction)
            }
        }
        .toast(message: viewModel.toastMessage)
    }

    private func toggleEditingLock() {
        let month = balanceMonths.first ?? {
            let month = BalanceMonth(monthStart: selectedMonth.startDate)
            modelContext.insert(month)
            return month
        }()
        month.isLocked.toggle()
        try? modelContext.save()
    }
}

#Preview {
    BalanceView(PreviewHelper.makeBalanceViewModel(), selectedMonth: FinanceMonth(.now))
        .modelContainer(
            PreviewContainer.shared.container
        )
}
