//
//  BudgetTransactionListView.swift
//  Presentation
//
//  Created by Tín Nguyễn on 15/10/26.
//

import SwiftUI
import Styleguide
import Utility

struct BudgetTransactionListView: View {
    @Environment(BudgetViewModel.self) private var viewModel: BudgetViewModel
    @State private var isDeleteConfirmationPresented: Bool = false
    
    private let transactions: [BudgetTransactionPresentationModel]
    private var groupedTransactions: [(date: Date, transactions: [BudgetTransactionPresentationModel])] {
        let grouped = Dictionary(grouping: transactions) { transaction in
            Calendar.current.startOfDay(for: transaction.date)
        }
        
        return grouped
            .map { (date: $0.key, transactions: $0.value) }
            .sorted { $0.date > $1.date }
    }
    
    init(transactions: [BudgetTransactionPresentationModel]) {
        self.transactions = transactions
    }
    
    var body: some View {
        AppList {
            ForEach(groupedTransactions, id: \.date) { group in
                Section {
                    ForEach(group.transactions) { transaction in
                        BudgetTransactionItemView(
                            transaction: transaction
                        )
                        .shadow(color: .primary.opacity(0.2), radius: 2, x: 1, y: 1)
                        .contextMenu {
                            Button(role: .destructive) {
                                isDeleteConfirmationPresented = true
                                viewModel.transactionPendingDeletionID = transaction.id
                            } label: {
                                Label(
                                    "common.delete".localized,
                                    systemImage: "trash"
                                )
                            }
                        }
                    }
                } header: {
                    BudgetTransactionHeaderView(dateNo: group.date.toString(withFormat: .dayNo))
                }
            }
            .deleteConfirmationDialog(
                isPresented: $isDeleteConfirmationPresented,
                title: "transaction.form.delete.confirmation.title".localized,
                message: "common.delete.warning".localized
            ) {
                viewModel.deleteTransaction()
            } cancelAction: {
                viewModel.transactionPendingDeletionID = nil
            }
        }
        .contentMargins(.vertical, 16)
        .onPullAction(.label ,isEnabled: true) {
            viewModel.createTransaction()
        }
        .listSectionSpacing(0)
    }
}
