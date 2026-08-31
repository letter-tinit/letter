//
//  BudgetTransactionGroupRowView.swift
//  Letter
//
//  Created by TiniT on 24/7/26.
//

import SwiftUI
import Domain
import Core
import Utility
import Styleguide

public struct BudgetTransactionGroupRowView: View {
    public let group: BudgetContentView.TransactionGroup
    @Binding var isExpand: Bool
    @Binding var selectedTransaction: BudgetTransaction?
    @Binding var transactionPendingDeletion: BudgetTransaction?
    
    private var totalAmount: Decimal {
        group.transactions.reduce(Decimal.zero) { partialResult, transaction in
            partialResult + transaction.amount
        }
    }
    
    public var body: some View {
        VStack {
            HStack {
                VStack {
                    Image(systemName: "\(group.date.toString(withFormat: .dayNo)).calendar")
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 48)
                    
                    Text(group.date.toString(withFormat: .custom("EEE")))
                        .customFont(.subheadline)
                }
                
                Spacer()
                
                VStack(alignment: .trailing) {
                    Button {
                        baseAnimation {
                            isExpand.toggle()
                        }
                    } label: {
                        Image(systemName: "chevron.right")
                            .rotationEffect(.degrees(
                                isExpand ? 90 : 0
                            ))
                    }
                    
                    Spacer()
                    
                    Text("- " + totalAmount.formattedVND)
                        .customFont(size: 20, weight: .bold)
                        .foregroundStyle(Color.Common.failure)
                }
            }
            
            if isExpand {
                VStack {
                    Divider()
                    
                    ForEach(group.transactions) { transaction in
                        Button {
                            selectedTransaction = transaction
                        } label: {
                            BudgetTransactionItemView(transaction: transaction)
                        }
                        .contextMenu {
                            Button(role: .destructive) {
                                transactionPendingDeletion = transaction
                            } label: {
                                Label("common.delete".localized, systemImage: "trash")
                            }
                        }
                        .disabled(!group.isEditingUnlocked)
                    }
                }
            }
        }
        .padding()
        .appGlassEffect(
            in: .rect(cornerRadius: 16)
        )
        .shadow(color: .primary.opacity(0.3), radius: 1)
    }
}
