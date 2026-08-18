//
//  TransactionInput.swift
//  Letter
//
//  Created by TiniT on 21/7/26.
//

import Foundation

struct TransactionInput: Equatable {
    var description: String
    var transactionType: TransactionType
    var category: TransactionCategory
    var occurredAt: Date
    var amountText: String
    var paymentMethod: PaymentMethod
    
    static var template: TransactionInput {
        return TransactionInput.init(
            description: "",
            transactionType: .income,
            category: .other,
            occurredAt: .now,
            amountText: "",
            paymentMethod: .banking
        )
    }
    
    private var amount: Decimal = .zero
    
    init(description: String, transactionType: TransactionType, category: TransactionCategory, occurredAt: Date, amountText: String, paymentMethod: PaymentMethod) {
        self.description = description
        self.transactionType = transactionType
        self.category = category
        self.occurredAt = occurredAt
        self.amountText = amountText
        self.paymentMethod = paymentMethod
    }
    
    init(transaction: Transaction) {
        self.description = transaction.note ?? ""
        self.transactionType = transaction.type
        self.category = transaction.category
        self.occurredAt = transaction.occurredAt
        self.amountText = transaction.amount.toAmountString
        self.paymentMethod = transaction.method
    }
    
    mutating func validate() throws {
        let normalizedAmount = amountText
            .replacingOccurrences(of: ".", with: "")
            .replacingOccurrences(of: ",", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)

        guard !normalizedAmount.isEmpty else {
            throw TransactionFormValidationError.amountRequired
        }

        guard let amount = Decimal(string: normalizedAmount) else {
            throw TransactionFormValidationError.invalidAmount
        }

        guard amount > 0 else {
            throw TransactionFormValidationError.amountMustBePositive
        }
        
        self.amount = amount
    }
    
    mutating func validatedInputTransaction() throws -> Transaction {
        try validate()

        return Transaction(
            note: description.trimmingCharacters(in: .whitespacesAndNewlines),
            type: transactionType,
            category: category,
            method: paymentMethod,
            amount: amount,
            occurredAt: occurredAt
        )
    }
    
    mutating func apply(to transaction: Transaction) throws {
        try validate()

        transaction.note = description.trimmingCharacters(in: .whitespacesAndNewlines)
        transaction.type = transactionType
        transaction.category = category
        transaction.method = paymentMethod
        transaction.amount = amount
        transaction.occurredAt = occurredAt
    }
}

enum TransactionFormValidationError: LocalizedError {
    case titleRequired
    case amountRequired
    case invalidAmount
    case amountMustBePositive
    
    var localizedDescription: String {
        switch self {
        case .titleRequired:
            "transaction.form.error.title".localized
        case .amountRequired:
            "transaction.form.error.amount.required".localized
        case .invalidAmount:
            "transaction.form.error.amount.invalid".localized
        case .amountMustBePositive:
            "transaction.form.error.amount.positive".localized
        }
    }
}
