//
//  TransactionInput.swift
//  Letter
//
//  Created by TiniT on 21/7/26.
//

import Foundation
import Utility

public struct TransactionInput: Equatable {
    public var description: String
    public var transactionType: TransactionType
    public var category: TransactionCategory
    public var occurredAt: Date
    public var amountText: String
    public var paymentMethod: PaymentMethod
    
    public static var template: TransactionInput {
        return TransactionInput.init(
            description: "",
            transactionType: .income,
            category: .other,
            occurredAt: .now,
            amountText: "",
            paymentMethod: .banking
        )
    }
    
    public init(description: String, transactionType: TransactionType, category: TransactionCategory, occurredAt: Date, amountText: String, paymentMethod: PaymentMethod) {
        self.description = description
        self.transactionType = transactionType
        self.category = category
        self.occurredAt = occurredAt
        self.amountText = amountText
        self.paymentMethod = paymentMethod
    }
    
    public init(transaction: Transaction) {
        self.description = transaction.note ?? ""
        self.transactionType = transaction.type
        self.category = transaction.category
        self.occurredAt = transaction.occurredAt
        self.amountText = transaction.amount.toAmountString
        self.paymentMethod = transaction.method
    }
    
}

public enum TransactionFormValidationError: LocalizedError {
    case titleRequired
    case amountRequired
    case invalidAmount
    case amountMustBePositive
    
    public var localizedDescription: String {
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
