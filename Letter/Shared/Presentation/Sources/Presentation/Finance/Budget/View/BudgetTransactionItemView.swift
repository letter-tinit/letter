//
//  BudgetTransactionItemView.swift
//  Presentation
//
//  Created by Tín Nguyễn on 15/10/26.
//

import SwiftUI

struct BudgetTransactionItemView: View {
    private let transaction: BudgetTransactionPresentationModel
    
    init(transaction: BudgetTransactionPresentationModel) {
        self.transaction = transaction
    }
    
    var body: some View {
        let category = transaction.category
        HStack {
            // MARK: - ICON
            ZStack {
                Color.clear
                    .frame(width: 44, height: 44)
                    .appGlassEffect(
                        .regular.tint(category.color.opacity(0.2)),
                        in: .rect(cornerRadius: 10)
                    )

                
                Image(systemName: category.icon)
                    .customFont(.title3)
                    .foregroundStyle(category.color)
            }
            
            // MARK: - NAME/DESCRIPTION
            VStack(alignment: .leading) {
                Text(category.localizedTitle)
                    .customFont(.headline, weight: .semibold)
                
                Text(transaction.description)
                    .customFont(.footnote, weight: .regular)
                    .foregroundStyle(.secondary)
            }
            
            Spacer()
            
            // MARK: - TRANSACTION INFO
            
            Text("- \(transaction.amount.formattedVND)")
                .customFont(.headline, weight: .semibold)
                .foregroundStyle(Color.Common.failure)

        }
        .padding(.top, 8)
        .padding(.horizontal)
        .padding(.bottom, 8)
    }
}
