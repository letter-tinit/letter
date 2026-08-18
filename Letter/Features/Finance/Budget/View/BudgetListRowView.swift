//
//  BudgetListRowView.swift
//  Letter
//
//  Created by TiniT on 23/7/26.
//

import SwiftUI

struct BudgetListRowView: View {
    let budget: Budget
    
    var body: some View {
        let isLocked = budget.isLocked
        HStack {
            if isLocked {
                Image(systemName: "lock")
                    .font(.system(size: 36))
            }
            
            VStack(alignment: .leading, spacing: 6) {
                Text(budget.name)
                    .customHeadline()
                    .foregroundStyle(.primary)
                
                Text("budget.create.method".localized)
                    .secondarySubHeadline()
            }
            
            Spacer()
            
            VStack(alignment: .trailing) {
                Text(budget.income.formattedVND)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.primary)
                
                Text(budget.method.localizationKey.localized)
                    .customSubHeadline()
                    .foregroundStyle(.secondary)
                    .padding(.vertical, 4)
                    .padding(.horizontal, 8)
                    .borderedBackground(fillColor: budget.method.color.opacity(0.3), lineWidth: 0)
            }
            
        }
        .padding(.vertical, 8)
        .foregroundStyle(isLocked ? .secondary : .primary)
    }
}
