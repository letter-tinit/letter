//
//  Budget.swift
//  Domain
//
//  Created by Tín Nguyễn on 15/10/26.
//

import Foundation
import Utility

public struct Budget {
    public let id: UUID
    
    /// The first day of the budget month.
    public let month: Date
    /// Actual creation timestamp; its day-of-month anchors monthly spending guidance.
    public let createdAt: Date
    
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
        createdAt: Date? = nil,
        isLocked: Bool,
        incomeAmount: Decimal,
        pyfAmount: Decimal,
        transactions: [BudgetTransaction]
    ) {
        self.id = id
        self.month = month
        self.createdAt = createdAt ?? month
        self.isLocked = isLocked
        self.incomeAmount = incomeAmount
        self.pyfAmount = pyfAmount
        self.transactions = transactions
    }
}

public struct BudgetDailySpendingGuidance: Equatable {
    public let nextBudgetDate: Date
    public let daysRemaining: Int
    public let amountPerDay: Decimal

    public init(nextBudgetDate: Date, daysRemaining: Int, amountPerDay: Decimal) {
        self.nextBudgetDate = nextBudgetDate
        self.daysRemaining = daysRemaining
        self.amountPerDay = amountPerDay
    }
}

public extension Budget {
    var remainingAmount: Decimal {
        incomeAmount - pyfAmount - transactions.reduce(.zero) { $0 + $1.amount }
    }

    func dailySpendingGuidance(cycleDay: Int, asOf date: Date, calendar: Calendar) -> BudgetDailySpendingGuidance {
        let today = calendar.startOfDay(for: date)
        let anchorDay = min(28, max(1, cycleDay))
        let currentMonth = calendar.startOfMonth(for: today)
        var nextBudgetDate = dateForAnchorDay(anchorDay, inMonthStarting: currentMonth, calendar: calendar)
        if nextBudgetDate <= today {
            let followingMonth = calendar.date(byAdding: .month, value: 1, to: currentMonth) ?? currentMonth
            nextBudgetDate = dateForAnchorDay(anchorDay, inMonthStarting: followingMonth, calendar: calendar)
        }

        let days = max(1, calendar.dateComponents([.day], from: today, to: nextBudgetDate).day ?? 1)
        var rawDailyAmount = remainingAmount / Decimal(days)
        var roundedDailyAmount = Decimal.zero
        NSDecimalRound(&roundedDailyAmount, &rawDailyAmount, -3, .down)
        return BudgetDailySpendingGuidance(
            nextBudgetDate: nextBudgetDate,
            daysRemaining: days,
            amountPerDay: roundedDailyAmount
        )
    }

    private func dateForAnchorDay(_ day: Int, inMonthStarting month: Date, calendar: Calendar) -> Date {
        let monthDays = calendar.range(of: .day, in: .month, for: month)?.count ?? day
        return calendar.date(byAdding: .day, value: min(day, monthDays) - 1, to: month) ?? month
    }
}

public struct BudgetTransaction {
    public let id: UUID
    public let amount: Decimal
    public let description: String
    public let date: Date
    public let category: BudgetTransactionCategory
    
    public init(
        id: UUID,
        amount: Decimal,
        description: String,
        date: Date,
        category: BudgetTransactionCategory
    ) {
        self.id = id
        self.amount = amount
        self.description = description
        self.date = date
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
