//
//  MonthPickerMenu.swift
//  Letter
//
//  Created by TiniT on 29/7/26.
//

import SwiftUI

struct MonthPickerMenu: View {
    @Binding var selectedMonth: FinanceMonth
    let months: [FinanceMonth]
    let monthsWithData: Set<FinanceMonth>
    var isTitle: Bool
    
    init(
        selectedMonth: Binding<FinanceMonth>,
        months: [FinanceMonth],
        monthsWithData: Set<FinanceMonth>,
        isUppercase: Bool = false
    ) {
        _selectedMonth = selectedMonth
        self.months = months
        self.monthsWithData = monthsWithData
        self.isTitle = isUppercase
    }
    
    var body: some View {
        Menu {
            ForEach(months) { month in
                Button {
                    Haptic.selection()
                    selectedMonth = month
                } label: {
                    if month == selectedMonth {
                        Label {
                            Text(monthTitle(for: month))
                        } icon: {
                            Image(systemName: "checkmark")
                        }
                    } else {
                        Text(monthTitle(for: month))
                    }
                }
            }
        } label: {
            Group {
                if isTitle {
                    Text(selectedMonth.title.uppercased())
                        .customFont(.headline, weight: .semibold)
                } else {
                    HStack(spacing: 4) {
                        Text(selectedMonth.title)
                            .customFont(.headline, weight: .semibold)
                        
                        Image(systemName: "chevron.down")
                            .customFont(.caption)
                    }
                }
            }
            .endTapHaptic()
        }
        .menuStyle(.button)
        .buttonStyle(.glass)
        .buttonBorderShape(.capsule)
    }
    
    private func monthTitle(for month: FinanceMonth) -> String {
        monthsWithData.contains(month) ? month.title : "\(month.title) ∅"
    }
}
