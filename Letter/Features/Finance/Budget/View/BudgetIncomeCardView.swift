//
//  BudgetIncomeCardView.swift
//  Letter
//
//  Created by TiniT on 23/7/26.
//

import SwiftUI

struct BudgetIncomeCardView: View {
    let budget: Budget
    var isPortrait: Bool
    
    var body: some View {
        Group {
            if isPortrait {
                VStack(alignment: .leading) {
                    Text("monthly.salary".localized)
                        .customSubHeadline()
                    
                    Text(budget.income.formattedVND)
                        .customTitle()
                    
                    Divider()
                    
                    HStack {
                        Text("budget.method".localized)
                            .customHeadline()
                        
                        Spacer()
                        
                        Text(budget.method.localizationKey.localized)
                            .customSubHeadline()
                            .padding(.horizontal, 10)
                            .padding(.vertical, 4)
                            .background(
                                Capsule()
                                    .foregroundStyle(budget.method.color.opacity(0.3))
                            )
                    }
                }
                .shadow(color: .primary.opacity(0.3), radius: 1, x: 1, y: 1)
                .foregroundStyle(Color.Common.surface)
                .padding()
                .frame(maxWidth: .infinity)
                .borderedBackground(linearGradient: LinearGradient(
                    gradient: .Glass.lavender,
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                ))
            } else {
                Text(budget.income.formattedVND)
                    .customSubHeadline()
                    .padding(.vertical, 4)
                    .padding(.horizontal, 8)
                    .frame(width: 160, alignment: .leading)
                    .customHeadline()
                    .borderedBackground(fillColor: Color.Common.success.opacity(0.5), cornerRadius: 8, lineWidth: 0)
            }
        }
    }
}
