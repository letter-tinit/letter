//
//  BalanceTransaction.swift
//  Letter
//
//  Created by TiniT on 20/7/26.
//

import Foundation
import Utility

public final class Transaction: Identifiable, Hashable {
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

    public static func == (lhs: Transaction, rhs: Transaction) -> Bool { lhs.id == rhs.id }

    public func hash(into hasher: inout Hasher) { hasher.combine(id) }
}

public extension Transaction {
    public func snapshot(from previousBalance: Decimal) -> Decimal {
        switch type {
        case .expense:
            return previousBalance - amount
        case .income:
            return previousBalance + amount
        }
    }
}

public enum TransactionCategory: String, CaseIterable, Codable, Identifiable {
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
    
    public var id: String {
        rawValue
    }
    
    public var titleKey: String {
        "transaction.category.\(rawValue)"
    }
    
    public var icon: String {
        switch self {
        case .food:
            "fork.knife"
        case .transport:
            "car"
        case .housing:
            "house"
        case .shopping:
            "bag"
        case .entertainment:
            "gamecontroller"
        case .health:
            "heart"
        case .education:
            "book"
        case .salary:
            "banknote"
        case .investment:
            "chart.line.uptrend.xyaxis"
        case .carryover:
            "checkmark.seal.text.page"
        case .other:
            "ellipsis.circle"
        }
    }
    
    public var localizedTitle: String {
        titleKey.localized
    }
}
