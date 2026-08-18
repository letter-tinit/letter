//
//  TransactionFormState.swift
//  Personal Finance
//
//  Created by TiniT on 14/7/26.
//

import Foundation

enum BudgetTransactionFormValidationError: Error, Equatable {
    case descriptionRequired
    case allocationRequired
    case invalidAmount
}

struct ValidatedBudgetTransactionInput: Equatable {
    let description: String
    let allocationID: UUID
    let amount: Decimal
    let occurredAt: Date
    let paymentMethod: PaymentMethod
    let note: String
}

struct TransactionFormState: Equatable {
    var description = ""
    var allocationID: UUID?
    var amountText = ""
    var occurredAt = Date.now
    var paymentMethod: PaymentMethod = .banking
    var note = ""

    init() {}

    init(transaction: BudgetTransaction) {
        description = transaction.title
        allocationID = transaction.allocation?.id ?? UUID()
        amountText = NSDecimalNumber(decimal: transaction.amount).stringValue
        occurredAt = transaction.occurredAt
        paymentMethod = transaction.paymentMethod
        note = transaction.note
    }

    init(fixedExpensePlan: FixedExpensePlan, occurredAt: Date = .now) {
        description = fixedExpensePlan.name
        allocationID = fixedExpensePlan.allocation?.id ?? UUID()
        amountText = NSDecimalNumber(decimal: fixedExpensePlan.amount).stringValue
        self.occurredAt = occurredAt
    }

    func validatedInput() throws -> ValidatedBudgetTransactionInput {
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
