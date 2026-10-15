//
//  Budget.swift
//  Domain
//
//  Created by Tín Nguyễn on 15/10/26.
//

import Foundation

public struct Budget {
    public let id: UUID
    
    /// The first day of the budget month.
    public let month: Date
    
    public let isLocked: Bool
    
    /// Actual income received during this budget month.
    public let incomeAmount: Decimal
    
    /// Amount allocated to Pay Yourself First.
    public let pyfAmount: Decimal
    
    /// Expenses only; does not include transfers or repayments.
    public let transactions: [BudgetTransaction]
    
    public init(
        id: UUID,
        month: Date,
        isLocked: Bool,
        incomeAmount: Decimal,
        pyfAmount: Decimal,
        transactions: [BudgetTransaction]
    ) {
        self.id = id
        self.month = month
        self.isLocked = isLocked
        self.incomeAmount = incomeAmount
        self.pyfAmount = pyfAmount
        self.transactions = transactions
    }
}

public struct BudgetTransaction {
    public let id: UUID
    public let amount: Decimal
    public let description: String
    public let date: Date
    public let category: ExpenseCategory
    
    public init(
        id: UUID,
        amount: Decimal,
        description: String,
        date: Date,
        category: ExpenseCategory
    ) {
        self.id = id
        self.amount = amount
        self.description = description
        self.date = date
        self.category = category
    }
}

public enum ExpenseCategory: String, CaseIterable, Identifiable {
    case bills
    case eWallet
    case food
    case transport
    case shopping
    case health
    case other
    
    public var id: Self { self }
}

public extension ExpenseCategory {
    var localizedTitle: String {
        switch self {
        case .bills: "Hóa đơn"
        case .eWallet: "Ví điện tử"
        case .food: "Ăn uống"
        case .transport: "Di chuyển"
        case .shopping: "Mua sắm"
        case .health: "Sức khỏe"
        case .other: "Khác"
        }
    }
    
    var icon: String {
        switch self {
        case .bills: "house"
        case .eWallet: "wallet.bifold"
        case .food: "fork.knife"
        case .transport: "car"
        case .shopping: "bag"
        case .health: "heart"
        case .other: "ellipsis"
        }
    }
}
