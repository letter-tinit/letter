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
    
    private let transactions: [BudgetTransactionPresentationModel]
    private var groupedTransactions: [(date: Date, transactions: [BudgetTransactionPresentationModel])] {
        let grouped = Dictionary(grouping: transactions) { transaction in
            Calendar.current.startOfDay(for: transaction.date)
        }
        
        return grouped
            .map { (date: $0.key, transactions: $0.value) }
            .sorted { $0.date > $1.date }
    }
    
    private let isLocked: Bool
    
    init(
        transactions: [BudgetTransactionPresentationModel],
        isLocked: Bool
    ) {
        self.transactions = transactions
        self.isLocked = isLocked
    }
    
    var body: some View {
        @Bindable var viewModel = viewModel
        AppList(scrollBounceBehavior: .always) {
            ForEach(groupedTransactions, id: \.date) { group in
                Section {
                    ForEach(group.transactions) { transaction in
                        BudgetTransactionItemView(
                            transaction: transaction
                        )
                        .contextMenu {
                            Button(role: .destructive) {
                                viewModel.didTapDeleteTransactionButton(transactionId: transaction.id)
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
                isPresented: $viewModel.transactionDeleteConfirmation,
                title: "transaction.form.delete.confirmation.title".localized,
                message: "common.delete.warning".localized
            ) {
                viewModel.didConfirmDeleteTransaction()
            } cancelAction: {
                viewModel.didCancelDeleteTransaction()
            }
        }
        .contentMargins(.vertical, 16)
        .onPullAction(.label ,isEnabled: !isLocked) {
            viewModel.didTapCreateNewTransaction()
        }
        .listSectionSpacing(0)
    }
}
