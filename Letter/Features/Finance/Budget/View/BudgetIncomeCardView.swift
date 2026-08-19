//
//  BudgetIncomeCardView.swift
//  Letter
//
//  Created by TiniT on 23/7/26.
//

import SwiftUI

struct BudgetIncomeCardView: View {
    let budget: Budget
    let isExpandAllTransaction: Bool
    let isEditingUnlocked: Bool
    let onToggleTransactionGroupsExpansion: () -> Void
    @Binding var isFixedPlanPresented: Bool
    @Binding var segmentOption: BudgetContentView.SegmentOption
    
    var body: some View {
        VStack(alignment: .leading) {
            HStack {
                Text("monthly.salary".localized)
                    .customSubHeadline()
                
                Spacer()
                
                Button {
                    Haptic.selection()
                    isFixedPlanPresented = true
                } label: {
                    Image(systemName: "gearshape")
                        .foregroundStyle(.primary)
                }
            }
            
            Text(budget.income.formattedVND)
                .customTitle()
            
            Divider()
            
            HStack {
                if segmentOption == .transaction {
                    Button(action: onToggleTransactionGroupsExpansion) {
                        Image(
                            systemName: isExpandAllTransaction
                            ? "rectangle.arrowtriangle.2.inward"
                            : "rectangle.arrowtriangle.2.outward"
                        )
                        .foregroundStyle(.black)
                    }
                    .endTapHaptic()
                    .buttonStyle(.glass)
                }
                
                Spacer()
                
                Menu {
                    ForEach(BudgetContentView.SegmentOption.allCases, id: \.self) { option in
                        let budgetName = budget.method.localizationKey.localized
                        Button {
                            Haptic.selection()
                            segmentOption = option
                        } label: {
                            if segmentOption == option {
                                Label(
                                    option.displayName(budgetName: budgetName),
                                    systemImage: "checkmark"
                                )
                            } else {
                                Text(option.displayName(budgetName: budgetName))
                            }
                        }
                    }
                } label: {
                    HStack {
                        Image(systemName: "display")
                        Text(
                            segmentOption.displayName(
                                budgetName: budget.method.localizationKey.localized
                            )
                        )
                        .customSubHeadline()
                        .lineLimit(1)
                    }
                    .frame(width: 140)
                }
                .padding(.top, 6)
                .menuStyle(.button)
                .buttonStyle(.glassProminent)
                .buttonBorderShape(.capsule)
                .tint(budget.method.color.opacity(0.4))
                .endTapHaptic()
            }
        }
        .foregroundStyle(Color.Common.surface)
        .padding()
        .frame(maxWidth: .infinity)
        .cardStyle(.Glass.lavender)
    }
}
