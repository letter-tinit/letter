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
    var isUppercase: Bool
    
    init(
        selectedMonth: Binding<FinanceMonth>,
        months: [FinanceMonth],
        monthsWithData: Set<FinanceMonth>,
        isUppercase: Bool = false
    ) {
        _selectedMonth = selectedMonth
        self.months = months
        self.monthsWithData = monthsWithData
        self.isUppercase = isUppercase
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
            HStack(spacing: 4) {
                let title = isUppercase ? selectedMonth.title.uppercased() : selectedMonth.title
                Text(title)
                    .font(.headline)
                
                Image(systemName: "chevron.down")
                    .font(.caption)
            }
            .endTapHaptic()
        }
    }
    
    private func monthTitle(for month: FinanceMonth) -> String {
        monthsWithData.contains(month) ? month.title : "\(month.title) ∅"
    }
}
