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
    
    public init(
        id: UUID,
        amount: Decimal,
        description: String,
        date: Date
    ) {
        self.id = id
        self.amount = amount
        self.description = description
        self.date = date
    }
}
