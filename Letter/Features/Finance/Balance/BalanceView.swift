//
//  BalanceView.swift
//  Letter
//
//  Created by TiniT on 16/7/26.
//

import SwiftUI
import SwiftData

struct BalanceView: View {
    @Environment(\.verticalSizeClass) private var verticalSizeClass
    @State private var viewModel: BalanceViewModel
    
    @Query
    private var transactions: [Transaction]
    
    var balance: Balance {
        Balance(transactions: transactions)
    }
    
    private var isPortrait: Bool {
        verticalSizeClass == .regular
    }
    
    init(_ viewModel: BalanceViewModel) {
        self.viewModel = viewModel
        
        let start = viewModel.selectedMonth.startOfMonth
        let end = Calendar.current.date(byAdding: .month, value: 1, to: start)!
        let predicate = #Predicate<Transaction> {
            $0.occurredAt >= start && $0.occurredAt < end
        }
        _transactions = Query(
            filter: predicate,
            sort: [SortDescriptor(\.occurredAt, order: .reverse)]
        )
    }
    
    var body: some View {
        BaseScreen($viewModel.title) {
            VStack {
                // MARK: - BALANCE VIEW
                if isPortrait {
                    BalanceCardView(balance: balance)
                        .padding(.horizontal)
                }

                // MARK: - TRANSACTIONS
                BalanceListView(transactions: balance.transactionRows)
                    .environment(viewModel)
            }
        }
        .navigationBarTitleDisplayMode(.automatic)
        .toolbar {
            ToolbarItem(placement: .principal) {
                MonthPickerMenu(
                    selectedMonth: $viewModel.selectedMonth,
                    months: viewModel.months()
                )
            }
            
            ToolbarItem(placement: .topBarLeading) {
                if !isPortrait {
                    BalanceCardView(balance: balance)
                }
            }
            .sharedBackgroundVisibility(.hidden)
            
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    viewModel.isCreateNewBalancePresented = true
                } label: {
                    Image(systemName: "plus")
                }
            }
        }
        .sheet(isPresented: $viewModel.isCreateNewBalancePresented) {
            NavigationStack {
                BalanceFormView(onSave: viewModel.addTransaction)
            }
        }
        .toast(message: viewModel.toastMessage)
    }
    
    private func createTransaction(_ transaction: Transaction) {
        viewModel.addTransaction(transaction)
    }
}

#Preview {
    BalanceView(PreviewHelper.makeBalanceViewModel())
        .modelContainer(
            PreviewContainer.shared.container
        )
}
