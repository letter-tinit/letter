//
//  BudgetPresentationModel.swift
//  Presentation
//
//  Created by Tín Nguyễn on 15/10/26.
//

import Foundation
import Domain

public struct BudgetPresentationModel: Identifiable {
    public let id: UUID
    
    /// The first day of the budget month.
    public let month: Date
    
    public let isLocked: Bool
    
    /// Actual income received during this budget month.
    public let incomeAmount: Decimal
    
    /// Amount allocated to Pay Yourself First.
    public let pyfAmount: Decimal
    
    /// Expenses only; does not include transfers or repayments.
    public let transactions: [BudgetTransactionPresentationModel]
    
    public init(domain: Budget) {
        self.id = domain.id
        self.month = domain.month
        self.isLocked = domain.isLocked
        self.incomeAmount = domain.incomeAmount
        self.pyfAmount = domain.pyfAmount
        self.transactions = domain.transactions.map({ BudgetTransactionPresentationModel(domain: $0) })
    }
}

extension BudgetPresentationModel {
    var spendingBudget: Decimal {
        incomeAmount - pyfAmount
    }
    
    var totalExpenseAmount: Decimal {
        transactions.reduce(Decimal.zero) {
            $0 + $1.amount
        }
    }
    
    var remainingAmount: Decimal {
        spendingBudget - totalExpenseAmount
    }
}

public struct BudgetTransactionPresentationModel: Identifiable {
    public let id: UUID
    public let amount: Decimal
    public let description: String
    public let date: Date
    public let category: ExpenseCategory
    
    public  init(domain: BudgetTransaction) {
        self.id = domain.id
        self.amount = domain.amount
        self.description = domain.description
        self.date = domain.date
        self.category = domain.category
    }
}
