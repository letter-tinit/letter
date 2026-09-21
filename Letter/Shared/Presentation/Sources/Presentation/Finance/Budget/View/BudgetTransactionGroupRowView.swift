//
//  BudgetTransactionGroupRowView.swift
//  Letter
//
//  Created by TiniT on 24/7/26.
//

import SwiftUI
import Domain
import Utility
import Styleguide

public struct BudgetTransactionGroupRowView: View {
    @Bindable var group: BudgetTransactionGroupModel
    @Binding var selectedTransaction: BudgetTransactionRowModel?
    @Binding var transactionPendingDeletionID: BudgetTransaction.ID?
    let isEditingUnlocked: Bool
    
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
                            group.isExpanded.toggle()
                        }
                    } label: {
                        Image(systemName: "chevron.right")
                            .rotationEffect(.degrees(
                                group.isExpanded ? 90 : 0
                            ))
                    }
                    
                    Spacer()
                    
                    Text("- " + group.totalAmount.formattedVND)
                        .customFont(size: 20, weight: .bold)
                        .foregroundStyle(Color.Common.failure)
                }
            }
            
            if group.isExpanded {
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
                                transactionPendingDeletionID = transaction.id
                            } label: {
                                Label(
                                    "common.delete".localized,
                                    systemImage: "trash"
                                )
                            }
                        }
                        .disabled(!isEditingUnlocked)
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
