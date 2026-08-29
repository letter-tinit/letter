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
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .frame(maxWidth: .infinity)
                    .appGlassEffect(
                        .regular.interactive(),
                        in: .rect(cornerRadius: 24)
                    )
            }
            .buttonStyle(.plain)
            .swipeActions(edge: .trailing) {
                if isEditingUnlocked {
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
            }
            .lineSpacing(0)
            .listRowInsets(EdgeInsets(top: 6, leading: 16, bottom: 6, trailing: 16))
            .listRowBackground(Color.clear)
            .listRowSeparator(.hidden)
        }
        .scrollIndicators(.hidden)
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .contentMargins(.top, 10, for: .scrollContent)
        .sheet(item: $selectedTransaction) { transaction in
            NavigationStack {
                BalanceFormView(transaction: transaction, onSave: balanceViewModel.saveTransaction)
                    .disabled(!isEditingUnlocked)
            }
        }
        .toast(message: balanceViewModel.toastMessage)
    }
}

#Preview {
    BalanceListView(transactions: [], isEditingUnlocked: false)
}
