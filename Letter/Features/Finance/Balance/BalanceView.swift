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
    
    @Query
    private var transactions: [Transaction]
    
    var balance: Balance {
        Balance(transactions: transactions)
    }
    
    init(_ viewModel: BalanceViewModel, selectedMonth: FinanceMonth) {
        self.viewModel = viewModel
        
        let start = selectedMonth.startDate
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
        BaseScreen {
            VStack {
                // MARK: - BALANCE VIEW
                BalanceCardView(balance: balance)
                    .padding(.horizontal)
                
                // MARK: - TRANSACTIONS
                BalanceListView(transactions: balance.transactionRows)
                    .environment(viewModel)
            }
        }
        .navigationBarTitleDisplayMode(.automatic)
        .toolbar {
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
    
}

#Preview {
    BalanceView(PreviewHelper.makeBalanceViewModel(), selectedMonth: FinanceMonth(.now))
        .modelContainer(
            PreviewContainer.shared.container
        )
}
