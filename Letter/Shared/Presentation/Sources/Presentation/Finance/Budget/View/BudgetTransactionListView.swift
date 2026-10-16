//
//  BudgetTransactionListView.swift
//  Presentation
//
//  Created by Tín Nguyễn on 15/10/26.
//

import SwiftUI
import Styleguide

struct BudgetTransactionListView: View {
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
                                // Delete transaction
                            } label: {
                                Label(
                                    "common.delete".localized,
                                    systemImage: "trash"
                                )
                            }
                        }
                    }
                } header: {
                    HStack {
                        Text("common.day".localized)
                            .customFont(.headline, weight: .semibold)
                        
                        Image(systemName: "\(group.date.toString(withFormat: .dayNo)).calendar")
                    }
                    .customFont(.title3)
                    .padding(.vertical, 4)
                    .padding(.horizontal, 16)
                    .appGlassEffect(
                        .regular.tint(.mint.opacity(0.2)),
                        in: .rect(cornerRadius: 4)
                    )
                    .frame(maxWidth: .infinity, alignment: .trailing)
                    .padding(.trailing)
                    .foregroundStyle(.primary)
                }
            }
        }
        .appListBottomSpacing(16)
        .pullAction(isEnabled: true) {
        } indicator: { _ in
            Image(systemName: "plus")
                .padding()
                .appGlassEffect(
                    in: .circle
                )
                .foregroundStyle(Color.Common.success)
                .accessibilityLabel("transaction.form.add".localized)
        }
        .listSectionSpacing(0)
    }
}
