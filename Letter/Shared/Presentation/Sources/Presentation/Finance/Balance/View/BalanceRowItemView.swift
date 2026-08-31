//
//  BalanceRowItemView.swift
//  Letter
//
//  Created by TiniT on 21/7/26.
//

import SwiftUI
import Domain
import Utility
import Styleguide

public struct BalanceRowItemView: View {
    public let rowModel: TransactionRowModel
    
    public var body: some View {
        let transaction = rowModel.transaction
        let color = transaction.type.color
        let sign = transaction.type == .income ? "+" : "-"
        let paymentMethod = transaction.method
        HStack(alignment: .center, spacing: 8) {
            // MARK: Time
            HStack {
                let transactionTime = transaction.occurredAt
                
                VStack {
                    Image(systemName: "\(transactionTime.toString(withFormat: .dayNo)).calendar")
                        .customFont(size: 36)
                    
                    Text(transactionTime.toString(withFormat: .custom("EEE")))
                        .customFont(.subheadline)
                }
            }
            
            Divider()
            
            // MARK: Description
            VStack(alignment: .leading) {
                HStack(spacing: 2) {
                    Image(systemName: transaction.category.icon)
                    
                    Text(transaction.category.localizedTitle)
                        .lineLimit(nil)
                    
                    Spacer()
                }
                .customFont(.subheadline, weight: .semibold)

                Text(transaction.note.isNullOrEmpty ? "common.nil.note".localized : transaction.note ?? "")
                    .customFont(.subheadline)
                    .lineLimit(nil)
            }
            
            // MARK: Transaction
            VStack(alignment: .trailing) {
                Text(paymentMethod.localizationKey.localized)
                .customFont(.caption)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(
                        Capsule()
                            .foregroundStyle(paymentMethod.color.opacity(0.3))
                    )
                
                Text("\(sign)\(transaction.amount.formattedVND)")
                    .customFont(.subheadline, weight: .semibold)
                    .foregroundStyle(color)
                
                Text(rowModel.balanceSnapshot.formattedVND)
                .customFont(.caption)
            }
        }
    }
}
