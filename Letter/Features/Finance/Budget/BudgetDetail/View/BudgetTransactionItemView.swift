//
//  BudgetTransactionItemView.swift
//  Personal Finance
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
                    .customNormalText()
                    .multilineTextAlignment(.leading)
                
                Spacer()
                
                Text(transaction.amount.formattedVND)
                    .customSubHeadline()
            }
            
            if !transaction.note.isEmpty {
                Text(transaction.note)
                    .secondarySubHeadline()
                    .multilineTextAlignment(.leading)
            }
        }
        .padding(.vertical, 4)
        .padding(.horizontal, 8)
        .borderedBackground(fillColor: color.opacity(0.1), cornerRadius: 8, lineWidth: 0)
    }
}
