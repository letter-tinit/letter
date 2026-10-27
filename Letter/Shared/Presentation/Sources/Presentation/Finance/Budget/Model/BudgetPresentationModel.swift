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
    
    public init(
        id: UUID,
        month: Date,
        isLocked: Bool,
        incomeAmount: Decimal,
        pyfAmount: Decimal,
        transactions: [BudgetTransactionPresentationModel]
    ) {
        self.id = id
        self.month = month
        self.isLocked = isLocked
        self.incomeAmount = incomeAmount
        self.pyfAmount = pyfAmount
        self.transactions = transactions
    }
    
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
    
    var noTransaction: Bool {
        transactions.isEmpty
    }
}

public struct BudgetTransactionPresentationModel: Identifiable {
    public let id: UUID
    public let amount: Decimal
    public let description: String
    public let date: Date
    public let category: BudgetTransactionCategory
    
    public init(
        id: UUID,
        amount: Decimal,
        description: String,
        date: Date, category:
        BudgetTransactionCategory
    ) {
        self.id = id
        self.amount = amount
        self.description = description
        self.date = date
        self.category = category
    }
    
    public  init(domain: BudgetTransaction) {
        self.id = domain.id
        self.amount = domain.amount
        self.description = domain.description
        self.date = domain.date
        self.category = domain.category
    }
}

public extension BudgetTransactionPresentationModel {
    var domain: BudgetTransaction {
        BudgetTransaction(
            id: id,
            amount: amount,
            description: description,
            date: date,
            category: category
        )
    }
}

public extension BudgetPresentationModel {
    var domain: Budget {
        Budget(
            id: id,
            month: month,
            isLocked: isLocked,
            incomeAmount: incomeAmount,
            pyfAmount: pyfAmount,
            transactions: transactions.map(\.domain)
        )
    }
}
