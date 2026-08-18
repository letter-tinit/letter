//
//  CurrencyInputFormatter.swift
//  Letter
//
//  Created by TiniT on 14/7/26.
//

import Foundation

@MainActor
enum CurrencyInputFormatter {
    private static let formatter: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.groupingSeparator = ","
        formatter.decimalSeparator = "."
        formatter.maximumFractionDigits = 0
        formatter.usesGroupingSeparator = true
        return formatter
    }()

    static func format(_ input: String) -> String {
        let digits = input.filter(\.isNumber)
        guard !digits.isEmpty,
              let amount = Decimal(string: digits),
              let formattedAmount = formatter.string(
                from: NSDecimalNumber(decimal: amount)
              ) else {
            return ""
        }

        return formattedAmount
    }
}
