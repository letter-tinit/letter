//
//  BudgetCardView.swift
//  Presentation
//
//  Created by Tín Nguyễn on 15/10/26.
//

import SwiftUI

public struct BudgetCardView: View {
    public let amount: String
    public let onFixedPlans: () -> Void

    public init(amount: String, onFixedPlans: @escaping () -> Void = {}) {
        self.amount = amount
        self.onFixedPlans = onFixedPlans
    }
    
    public var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text("budget.title".localized)
                    .customFont(.headline, weight: .semibold)
                
                Spacer()
                
                Button {
                    onFixedPlans()
                } label: {
                    Image(systemName: "wallet.bifold")
                        .customFont(.title2)
                        .accessibilityHidden(true)
                }
                .accessibilityLabel("budget.fixedPlan.title".localized)
            }
            
            Text(amount)
                .customFont(.title, weight: .bold)
            
            Label("message to warning", image: "exclamationmark.circle.fill")
                .customFont(.footnote, weight: .medium)
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .cardStyle(.Glass.lavender)
    }
}
