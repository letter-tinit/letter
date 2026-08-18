//
//  BudgetSengmentSelectionView.swift
//  Personal Finance
//
//  Created by TiniT on 23/7/26.
//

import SwiftUI

struct BudgetSengmentSelectionView: View {
    @Binding var selectedSegment: BudgetDetailScreen.SegmentOption
    var body: some View {
        Picker("budget.view.mode".localized, selection: $selectedSegment) {
            ForEach(BudgetDetailScreen.SegmentOption.allCases, id: \.self) { option in
                Text(option.localizationKey.localized)
            }
        }
        .pickerStyle(.segmented)
        .labelsHidden()
    }
}

#Preview {
    BudgetSengmentSelectionView(selectedSegment: .constant(.overview))
}
