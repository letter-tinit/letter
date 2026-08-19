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
    
    init(
        selectedMonth: Binding<FinanceMonth>,
        months: [FinanceMonth]
    ) {
        _selectedMonth = selectedMonth
        self.months = months
    }

    var body: some View {
        Menu {
                ForEach(months) { month in
                Button {
                    selectedMonth = month
                } label: {
                    if month == selectedMonth {
                        Label {
                            Text(month.title)
                        } icon: {
                            Image(systemName: "checkmark")
                        }
                    } else {
                        Text(month.title)
                    }
                }
            }
        } label: {
            HStack(spacing: 4) {
                Text(selectedMonth.title)
                    .font(.headline)

                Image(systemName: "chevron.down")
                    .font(.caption)
            }
        }
    }
}
