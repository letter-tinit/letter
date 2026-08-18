//
//  MonthPickerMenu.swift
//  Personal Finance
//
//  Created by TiniT on 29/7/26.
//

import SwiftUI

struct MonthPickerMenu: View {
    @Binding var selectedMonth: Date
    let months: [Date]
    
    init(
        selectedMonth: Binding<Date>,
        months: [Date]
    ) {
        _selectedMonth = selectedMonth
        self.months = months
    }

    var body: some View {
        Menu {
            ForEach(months, id: \.self) { month in
                Button {
                    selectedMonth = month
                } label: {
                    if Calendar.current.isDate(month, equalTo: selectedMonth, toGranularity: .month) {
                        Label {
                            Text(month.toString(withFormat: .monthAndYear))
                        } icon: {
                            Image(systemName: "checkmark")
                        }
                    } else {
                        Text(month.toString(withFormat: .monthAndYear))
                    }
                }
            }
        } label: {
            HStack(spacing: 4) {
                Text(selectedMonth.toString(withFormat: .monthAndYear))
                    .font(.headline)

                Image(systemName: "chevron.down")
                    .font(.caption)
            }
        }
    }
}
