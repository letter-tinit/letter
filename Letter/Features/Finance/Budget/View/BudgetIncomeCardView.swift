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
        let budgetColor: Color = budget.method.color
        let segmentImageName = segmentOption == .transaction
        ? "clock.arrow.trianglehead.counterclockwise.rotate.90"
        : "wallet.bifold"
        
        VStack(alignment: .leading) {
            HStack {
                Text("monthly.salary".localized)
                    .customFont(.subheadline, weight: .semibold)
                
                Spacer()
                
                Button {
                    Haptic.selection()
                    isFixedPlanPresented = true
                } label: {
                    Image(systemName: "gearshape")
                }
            }
            
            Text(budget.income.formattedVND)
                .customFont(.title, weight: .bold)
            
            Divider()
            
            HStack {
                if segmentOption == .transaction {
                    Button(action: onToggleTransactionGroupsExpansion) {
                        Image(
                            systemName: isExpandAllTransaction
                            ? "rectangle.arrowtriangle.2.inward"
                            : "rectangle.arrowtriangle.2.outward"
                        )
                        .foregroundStyle(budgetColor)
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
                        Image(systemName: segmentImageName)
                                             
                        Text(
                            segmentOption.displayName(
                                budgetName: budget.method.localizationKey.localized
                            )
                        )
                        .customFont(.subheadline, weight: .semibold)
                        .lineLimit(1)
                    }
                    .frame(width: 140)
                }
                .padding(.top, 6)
                .menuStyle(.button)
                .buttonStyle(.glassProminent)
                .buttonBorderShape(.capsule)
                .tint(budgetColor)
                .endTapHaptic()
            }
        }
        .padding()
        .frame(maxWidth: .infinity)
        .cardStyle(.Glass.lavender)
    }
}
