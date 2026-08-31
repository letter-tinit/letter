//
//  BalanceTransaction.swift
//  Letter
//
//  Created by TiniT on 20/7/26.
//

import Foundation

public struct Transaction: Identifiable, Hashable {
    public var id: UUID
    
    /// This also called description
    public var note: String?
    
    public var type: TransactionType
    public var category: TransactionCategory
    public var method: PaymentMethod
    
    public var amount: Decimal
    
    public var occurredAt: Date
    public var createAt: Date
    
    public init(id: UUID = UUID(), note: String? = nil, type: TransactionType, category: TransactionCategory, method: PaymentMethod, amount: Decimal, occurredAt: Date, createAt: Date = .now) {
        self.id = id
        self.note = note
        self.type = type
        self.category = category
        self.method = method
        self.amount = amount
        self.occurredAt = occurredAt
        self.createAt = createAt
    }

}

public enum TransactionCategory: String, CaseIterable, Codable, Hashable {
    case food
    case transport
    case housing
    case shopping
    case entertainment
    case health
    case education
    case salary
    case investment
    case carryover
    case other
}
