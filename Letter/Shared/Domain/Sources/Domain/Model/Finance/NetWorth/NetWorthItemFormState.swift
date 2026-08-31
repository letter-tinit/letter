//
//  NetWorthItemFormState.swift
//  Letter
//

import Foundation
import Utility

public struct NetWorthItemFormState {
    public var category: NetWorthCategory = .cashAndCashEquivalents
    public var name = ""
    public var amountText = ""

    public init() {}

    public init(item: NetWorthPlanItem, amount: Decimal?) {
        category = item.category
        name = item.name
        amountText = amount.map { NSDecimalNumber(decimal: $0).stringValue } ?? ""
    }

    public func validatedInput() throws -> ValidatedNetWorthItemInput {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else {
            throw NetWorthItemFormValidationError.nameRequired
        }

        let normalizedAmount = amountText.replacingOccurrences(of: ",", with: "")
        guard let amount = Decimal(string: normalizedAmount), amount >= .zero else {
            throw NetWorthItemFormValidationError.invalidAmount
        }

        return ValidatedNetWorthItemInput(
            category: category,
            name: trimmedName,
            amount: amount
        )
    }
}

public struct ValidatedNetWorthItemInput {
    public let category: NetWorthCategory
    public let name: String
    public let amount: Decimal
}

public enum NetWorthItemFormValidationError: Error {
    case nameRequired
    case invalidAmount
}
