//
//  TransactionFormState.swift
//  Letter
//
//  Created by TiniT on 14/7/26.
//

import Foundation
import Domain
import Core
import Utility
import Styleguide

public enum BudgetTransactionFormValidationError: Error, Equatable {
    case descriptionRequired
    case allocationRequired
    case invalidAmount
}

public struct TransactionFormState: Equatable {
    public var description = ""
    public var allocationID: UUID?
    public var amountText = ""
    public var occurredAt = Date.now
    public var paymentMethod: PaymentMethod = .banking
    public var note = ""

    public init() {}

    public init(transaction: BudgetTransaction) {
        description = transaction.title
        allocationID = transaction.allocation?.id ?? UUID()
        amountText = NSDecimalNumber(decimal: transaction.amount).stringValue
        occurredAt = transaction.occurredAt
        paymentMethod = transaction.paymentMethod
        note = transaction.note
    }

    public init(fixedExpensePlan: FixedExpensePlan, occurredAt: Date = .now) {
        description = fixedExpensePlan.name
        allocationID = fixedExpensePlan.allocation?.id ?? UUID()
        amountText = NSDecimalNumber(decimal: fixedExpensePlan.amount).stringValue
        self.occurredAt = occurredAt
    }

    public func validatedInput() throws -> ValidatedBudgetTransactionInput {
        let trimmedDescription = description.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedDescription.isEmpty else {
            throw BudgetTransactionFormValidationError.descriptionRequired
        }

        guard let allocationID else {
            throw BudgetTransactionFormValidationError.allocationRequired
        }

        let normalizedAmount = amountText
            .replacingOccurrences(of: ".", with: "")
            .replacingOccurrences(of: ",", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)

        guard let amount = Decimal(string: normalizedAmount), amount > 0 else {
            throw BudgetTransactionFormValidationError.invalidAmount
        }

        return ValidatedBudgetTransactionInput(
            description: trimmedDescription,
            allocationID: allocationID,
            amount: amount,
            occurredAt: occurredAt,
            paymentMethod: paymentMethod,
            note: note.trimmingCharacters(in: .whitespacesAndNewlines)
        )
    }
}
