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
    
    public var isLocked: Bool
    
    /// Actual income received during this budget month.
    public let incomeAmount: Decimal
    
    /// Amount allocated to Pay Yourself First.
    public let pyfAmount: Decimal
    
    /// Expenses only; does not include transfers or repayments.
    public var transactions: [BudgetTransaction]
    
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
    public let category: BudgetTransactionCategory
    public let fixedPlanID: UUID?
    
    public init(
        id: UUID,
        amount: Decimal,
        description: String,
        date: Date,
        category: BudgetTransactionCategory,
        fixedPlanID: UUID? = nil
    ) {
        self.id = id
        self.amount = amount
        self.description = description
        self.date = date
        self.category = category
        self.fixedPlanID = fixedPlanID
    }
}

public struct BudgetFixedPlan: Identifiable, Equatable {
    public let id: UUID
    public var description: String
    public var amount: Decimal
    public var category: BudgetTransactionCategory

    public init(id: UUID = UUID(), description: String, amount: Decimal, category: BudgetTransactionCategory) {
        self.id = id
        self.description = description
        self.amount = amount
        self.category = category
    }
}

public enum BudgetTransactionCategory: String, CaseIterable, Identifiable {
    case bills
    case eWallet
    case food
    case transport
    case shopping
    case health
    case other
    
    public var id: Self { self }
}

public extension BudgetTransactionCategory {
    var localizedTitle: String {
        switch self {
        case .bills: "budget.transaction.category.title.bills".localized
        case .eWallet: "budget.transaction.category.title.ewallet".localized
        case .food: "budget.transaction.category.title.food".localized
        case .transport: "budget.transaction.category.title.transport".localized
        case .shopping: "budget.transaction.category.title.shopping".localized
        case .health: "budget.transaction.category.title.health".localized
        case .other: "budget.transaction.category.title.other".localized
        }
    }
    
    var icon: String {
        switch self {
        case .bills: "text.page"
        case .eWallet: "wallet.bifold"
        case .food: "fork.knife"
        case .transport: "car"
        case .shopping: "cart"
        case .health: "heart"
        case .other: "ellipsis"
        }
    }
    
    var defaultDescription: String {
        switch self {
        case .bills: "budget.transaction.category.description.bills".localized
        case .eWallet: "budget.transaction.category.description.ewallet".localized
        case .food: "budget.transaction.category.description.food".localized
        case .transport: "budget.transaction.category.description.transport".localized
        case .shopping: "budget.transaction.category.description.shopping".localized
        case .health: "budget.transaction.category.description.health".localized
        case .other: "budget.transaction.category.description.other".localized
        }
    }
}
