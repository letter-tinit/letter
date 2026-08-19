//
//  BalanceRowItemView.swift
//  Letter
//
//  Created by TiniT on 21/7/26.
//

import SwiftUI

struct BalanceRowItemView: View {
    let rowModel: TransactionRowModel
    
    var body: some View {
        let transaction = rowModel.transaction
        let color = transaction.type.color
        let sign = transaction.type == .income ? "+" : "-"
        let paymentMethod = transaction.method
        HStack(alignment: .center, spacing: 8) {
            HStack {
                let transactionTime = transaction.occurredAt
                
                VStack {
                    Image(systemName: "\(transactionTime.toString(withFormat: .dayNo)).calendar")
                        .font(.system(size: 36))
                    
                    Text(transactionTime.toString(withFormat: .custom("EEE")))
                        .secondarySubHeadline()
                }
            }
            
            Divider()
            
            VStack(alignment: .leading) {
                HStack {
                    Image(systemName: transaction.category.icon)
                    
                    Text(transaction.category.localizedTitle)
                        .lineLimit(nil)
                    
                    Spacer()
                }
                .customSubHeadline()

                Text(transaction.note.isNullOrEmpty ? "common.nil.note".localized : transaction.note ?? "")
                    .secondarySubHeadline()
                    .lineLimit(nil)
            }
            
            VStack(alignment: .trailing) {
                Text(paymentMethod.localizationKey.localized)
                    .font(.caption)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(
                        Capsule()
                            .foregroundStyle(paymentMethod.color.opacity(0.3))
                    )
                
                Text("\(sign)\(transaction.amount.formattedVND)")
                    .customSubHeadline()
                    .foregroundStyle(color)
                
                Text(rowModel.balanceSnapshot.formattedVND)
                    .font(.caption)
            }
        }
    }
}
