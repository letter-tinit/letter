//
//  BalanceListView.swift
//  Letter
//
//  Created by TiniT on 16/7/26.
//

import SwiftUI

struct BalanceListView: View {
    @Environment(BalanceViewModel.self) private var balanceViewModel: BalanceViewModel
    @State private var selectedTransaction: Transaction?
    
    let transactions: [TransactionRowModel]
    let isEditingUnlocked: Bool

    init(transactions: [TransactionRowModel], isEditingUnlocked: Bool = false) {
        self.transactions = transactions
        self.isEditingUnlocked = isEditingUnlocked
    }

    var body: some View {
        List(transactions) { rowModel in
            Button {
                selectedTransaction = rowModel.transaction
            } label: {
                BalanceRowItemView(rowModel: rowModel)
            }
            .disabled(!isEditingUnlocked)
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
                .disabled(!isEditingUnlocked)
            }
            .lineSpacing(0)
        }
        .scrollIndicators(.hidden)
        .listStyle(.insetGrouped)
        .contentMargins(.top, 10, for: .scrollContent)
        .sheet(item: $selectedTransaction) { transaction in
            NavigationStack {
                BalanceFormView(transaction: transaction, onSave: balanceViewModel.updateTransaction)
            }
        }
        .toast(message: balanceViewModel.toastMessage)
    }
}

#Preview {
    BalanceListView(transactions: [], isEditingUnlocked: false)
}
