//
//  BalanceList.swift
//  Personal Finance
//
//  Created by TiniT on 16/7/26.
//

import SwiftUI

struct BalanceList: View {
    @Environment(BalanceViewModel.self) private var balanceViewModel: BalanceViewModel
    @State private var selectedTransaction: Transaction?
    
    let transactions: [TransactionRowModel]
    private var groupedTransactions: [YearMonthGroup<TransactionRowModel>] {
        transactions.groupedByYearMonth { $0.transaction.occurredAt }.sorted { $0.originalDate > $1.originalDate }
    }
    
    var body: some View {
        Group {
            if !groupedTransactions.isEmpty {
                List(groupedTransactions) { group in
                    ForEach(group.items) { rowModel in
                        Section(group.title) {
                            Button {
                                selectedTransaction = rowModel.transaction
                            } label: {
                                BalanceRowItem(rowModel: rowModel)
                            }
                            .swipeActions(edge: .trailing) {
                                Button {
                                    balanceViewModel.removeTransaction(rowModel.transaction)
                                } label: {
                                    Label(
                                        "common.delete".localized,
                                        systemImage: "trash"
                                    )
                                }
                                .tint(Color.Common.failure)
                            }
                            .lineSpacing(0)
                        }
                    }
                }
                .scrollIndicators(.hidden)
                .scrollContentBackground(.hidden)
                .listStyle(.grouped)
            } else {
                CommonEmptyView()
            }
        }
        .sheet(item: $selectedTransaction) { transaction in
            NavigationStack {
                BalanceFormView(transaction: transaction, onSave: balanceViewModel.updateTransaction)
            }
        }
        .toast(message: balanceViewModel.toastMessage)
    }
}

#Preview {
    BalanceList(transactions: [])
}
