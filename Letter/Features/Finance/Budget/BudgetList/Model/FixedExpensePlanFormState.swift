//
//  FixedExpensePlanFormState.swift
//  Personal Finance
//
//  Created by TiniT on 14/7/26.
//

import Foundation

enum FixedExpensePlanFormValidationError: Error, Equatable {
    case nameRequired
    case invalidAmount
}

struct ValidatedFixedExpensePlanInput: Equatable {
    let name: String
    let amount: Decimal
    let amountType: FixedExpensePlanAmountType
}

struct FixedExpensePlanFormState: Equatable {
    var name = ""
    var amountText = ""
    var amountType: FixedExpensePlanAmountType = .estimated

    init() {}

    init(plan: FixedExpensePlan) {
        name = plan.name
        amountText = NSDecimalNumber(decimal: plan.amount).stringValue
        amountType = plan.amountType
    }

    func validatedInput() throws -> ValidatedFixedExpensePlanInput {
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
