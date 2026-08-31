//
//  YearPickerSheet.swift
//  Letter
//
//  Created by TiniT on 22/7/26.
//

import SwiftUI
import Domain
import Core
import Utility

public struct YearPickerSheet: View {
    @Environment(\.dismiss) private var dismiss

    @State private var year: Int
    private let years: [Int]
    
    private let onCreate: ((Int) -> Void)?

    public init(
        pastYears: Int = 20,
        futureYears: Int = 5,
        onCreate: ((Int) -> Void)? = nil
    ) {
        let currentYear = Calendar.current.component(.year, from: .now)
        _year = State(initialValue: currentYear)
        years = Array(
            (currentYear - pastYears)...(currentYear + futureYears)
        )
        self.onCreate = onCreate
    }

    public var body: some View {
        NavigationStack {
            VStack {
                AppPicker(
                    "common.year".localized,
                    selection: $year,
                    layout: .control
                ) {
                    ForEach(years, id: \.self) { year in
                        Text(String(year))
                            .tag(year)
                    }
                }
                .pickerStyle(.wheel)
            }
            .navigationTitle("common.year.select")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("common.cancel") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("common.done") {
                        onCreate?(year)
                        dismiss()
                    }
                }
            }
        }
    }
}

#Preview {
    YearPickerSheet()
}
