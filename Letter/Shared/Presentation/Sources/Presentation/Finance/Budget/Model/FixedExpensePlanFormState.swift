//
//  FixedExpensePlanFormState.swift
//  Letter
//
//  Created by TiniT on 14/7/26.
//

import Foundation
import Domain
import Utility
import Styleguide

public enum FixedExpensePlanFormValidationError: Error, Equatable {
    case nameRequired
    case invalidAmount
}

public struct FixedExpensePlanFormState: Equatable {
    public var name = ""
    public var amountText = ""
    public var amountType: FixedExpensePlanAmountType = .estimated

    public init() {}

    public init(plan: FixedExpensePlan) {
        name = plan.name
        amountText = NSDecimalNumber(decimal: plan.amount).stringValue
        amountType = plan.amountType
    }

    public func validatedInput() throws -> ValidatedFixedExpensePlanInput {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else {
            throw FixedExpensePlanFormValidationError.nameRequired
        }

        let normalizedAmount = amountText
            .replacingOccurrences(of: ".", with: "")
            .replacingOccurrences(of: ",", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)

        guard !normalizedAmount.isEmpty,
              let amount = Decimal(string: normalizedAmount),
              amount >= 0 else {
            throw FixedExpensePlanFormValidationError.invalidAmount
        }

        return ValidatedFixedExpensePlanInput(
            name: trimmedName,
            amount: amount,
            amountType: amountType
        )
    }
}
