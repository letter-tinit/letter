//
//  BudgetCardView.swift
//  Presentation
//
//  Created by Tín Nguyễn on 15/10/26.
//

import SwiftUI

public struct BudgetCardView: View {
    public let amount: String
    public let dailyGuidance: String
    public let onTransactionTemplates: () -> Void

    public init(amount: String, dailyGuidance: String = "", onTransactionTemplates: @escaping () -> Void = {}) {
        self.amount = amount
        self.dailyGuidance = dailyGuidance
        self.onTransactionTemplates = onTransactionTemplates
    }
    
    public var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text("budget.title".localized)
                    .customFont(.headline, weight: .semibold)
                
                Spacer()
                
                Button {
                    onTransactionTemplates()
                } label: {
                    Image(systemName: "wallet.bifold")
                        .customFont(.title2)
                        .accessibilityHidden(true)
                }
                .accessibilityLabel("budget.transactionTemplate.title".localized)
            }
            
            Text(amount)
                .customFont(.title, weight: .bold)
            
            Label(dailyGuidance, systemImage: "exclamationmark.circle")
                .customFont(.footnote, weight: .medium)
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .cardStyle(.Glass.lavender)
    }
}
