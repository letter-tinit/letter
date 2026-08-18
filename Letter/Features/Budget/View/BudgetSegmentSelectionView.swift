//
//  BudgetSegmentSelectionView.swift
//  Letter
//
//  Created by TiniT on 23/7/26.
//

import SwiftUI

struct BudgetSegmentSelectionView: View {
    @Binding var selectedSegment: BudgetDetailView.SegmentOption
    var body: some View {
        Picker("budget.view.mode".localized, selection: $selectedSegment) {
            ForEach(BudgetDetailView.SegmentOption.allCases, id: \.self) { option in
                Text(option.localizationKey.localized)
            }
        }
        .pickerStyle(.segmented)
        .labelsHidden()
    }
}

#Preview {
    BudgetSegmentSelectionView(selectedSegment: .constant(.overview))
}
