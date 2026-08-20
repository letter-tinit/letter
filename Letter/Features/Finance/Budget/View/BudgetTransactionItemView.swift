//
//  BudgetTransactionItemView.swift
//  Letter
//
//  Created by TiniT on 24/7/26.
//

import SwiftUI

struct BudgetTransactionItemView: View {
    let transaction: BudgetTransaction
    
    var body: some View {
        let color = transaction.allocation?.kind.topicColor ?? .primary
        
        VStack(alignment: .leading) {
            HStack {
                Text(transaction.title)
                    .customFont(.body)
                    .multilineTextAlignment(.leading)
                
                Spacer()
                
                Text(transaction.amount.formattedVND)
                    .customFont(.subheadline, weight: .semibold)
            }
            
            if !transaction.note.isEmpty {
                Text(transaction.note)
                    .customFont(.subheadline)
                    .multilineTextAlignment(.leading)
            }
        }
        .padding(.vertical, 4)
        .padding(.horizontal, 8)
        .borderedBackground(fillColor: color.opacity(0.1), cornerRadius: 8, lineWidth: 0)
    }
}
