//
//  MonthYearPickerSheet.swift
//  Letter
//
//  Created by TiniT on 16/7/26.
//

import SwiftUI

struct MonthYearPickerSheet: View {
    @Environment(\.dismiss) private var dismiss
    @State private var title: String = "salary.budget".localized

    @Binding var selectedDate: Date

    @State private var month: Int
    @State private var year: Int

    private let calendar = Calendar.current
    private let months = Calendar.current.monthSymbols

    private let years: [Int]

    init(selectedDate: Binding<Date>, yearRange: ClosedRange<Int> = 2020...2035) {
        _selectedDate = selectedDate

        let components = Calendar.current.dateComponents([.month, .year], from: selectedDate.wrappedValue)

        _month = State(initialValue: components.month ?? 1)
        _year = State(initialValue: components.year ?? Calendar.current.component(.year, from: .now))

        years = Array(yearRange)
    }

    var body: some View {
        NavigationStack {
            VStack {
                HStack {
                    Picker("Month", selection: $month) {
                        ForEach(1...12, id: \.self) { index in
                            Text(months[index - 1])
                                .tag(index)
                        }
                    }

                    Picker("Year", selection: $year) {
                        ForEach(years, id: \.self) { year in
                            Text(String(year))
                                .tag(year)
                        }
                    }
                }
                .pickerStyle(.wheel)
            }
            .navigationTitle("Budget Period")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        let components = DateComponents(
                            year: year,
                            month: month,
                            day: 1
                        )

                        if let date = calendar.date(from: components) {
                            selectedDate = date
                        }

                        dismiss()
                    }
                }
            }
        }
    }
}
