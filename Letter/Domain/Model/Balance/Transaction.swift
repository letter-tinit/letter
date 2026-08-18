//
//  BalanceTransaction.swift
//  Letter
//
//  Created by TiniT on 20/7/26.
//

import SwiftData
import Foundation

@Model
final class Transaction: Identifiable {
    var id: UUID
    
    /// This also called description
    var note: String?
    
    var type: TransactionType
    var category: TransactionCategory
    var method: PaymentMethod
    
    var amount: Decimal
    
    var occurredAt: Date
    var createAt: Date
    
    init(id: UUID = UUID(), note: String? = nil, type: TransactionType, category: TransactionCategory, method: PaymentMethod, amount: Decimal, occurredAt: Date, createAt: Date = .now) {
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

extension Transaction {
    static func makeBudgetCarryoverTransaction(_ amount: Decimal) -> Transaction {
        .init(
            note: AppConstant.Transaction.BudgetCarryoverNote,
            type: .income,
            category: .carryover,
            method: .banking,
            amount: amount,
            occurredAt: .now,
            createAt: .now
        )
    }
    
    func snapshot(from previousBalance: Decimal) -> Decimal {
        switch type {
        case .expense:
            return previousBalance - amount
        case .income:
            return previousBalance + amount
        }
    }
}

enum TransactionCategory: String, CaseIterable, Codable, Identifiable {
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
    
    var id: String {
        rawValue
    }
    
    var titleKey: String {
        "transaction.category.\(rawValue)"
    }
    
    var icon: String {
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
    
    var localizedTitle: String {
        titleKey.localized
    }
}
