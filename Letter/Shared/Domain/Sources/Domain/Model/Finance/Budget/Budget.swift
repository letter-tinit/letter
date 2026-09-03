//
//  Budget.swift
//  Letter
//
//  Created by TiniT on 13/7/26.
//
import Foundation
import Utility

public enum BudgetError: Error {
    case budgetNotFound
    case invalidAmount
    case invalidTransactionType
    case allocationNotFound
    case transactionNotFound
    case fixedExpensePlanNotFound
    case fixedExpensePlanAlreadyCompleted
    case invalidFixedExpensePlanAmount
    case unsupportedFixedExpensePlanAllocation
    case duplicatePeriod
}

public final class Budget: Identifiable, Hashable {
    public var id: UUID = UUID()
    public var periodStart: Date = Date()
    public var income: Decimal = 0
    public var isLocked: Bool = false
    public var method: BudgetMethod = BudgetMethod.fiftyThirtyTwenty
    public var createdAt: Date = Date()
    
    public var allocations: [BudgetAllocation] = []
    
    public var fixedExpensePlans: [FixedExpensePlan] = []
    
    public var transactions: [BudgetTransaction] = []
    
    public init(id: UUID = UUID(), periodStart: Date, income: Decimal, method: BudgetMethod, createdAt: Date = .now) {
        self.id = id
        self.periodStart = periodStart
        self.income = income
        self.method = method
        self.createdAt = createdAt
    }

    public static func == (lhs: Budget, rhs: Budget) -> Bool { lhs.id == rhs.id }

    public func hash(into hasher: inout Hasher) { hasher.combine(id) }
}

public final class BudgetTransaction: Identifiable, Hashable {
    public var id: UUID = UUID()
    public var budget: Budget?
    public var allocation: BudgetAllocation?
    public var type: TransactionType = TransactionType.expense
    public var title: String = ""
    public var note: String = ""
    public var occurredAt: Date = Date()
    public var amount: Decimal = 0
    public var paymentMethod: PaymentMethod = PaymentMethod.banking
    
    public var fixedExpensePlan: FixedExpensePlan?
    
    public init(id: UUID = UUID(), budget: Budget? = nil, allocation: BudgetAllocation? = nil, type: TransactionType = .expense, title: String, note: String = "", occurredAt: Date = .now, amount: Decimal, paymentMethod: PaymentMethod) {
        self.id = id
        self.budget = budget
        self.allocation = allocation
        self.type = type
        self.title = title
        self.note = note
        self.occurredAt = occurredAt
        self.amount = amount
        self.paymentMethod = paymentMethod
    }

    public static func == (lhs: BudgetTransaction, rhs: BudgetTransaction) -> Bool { lhs.id == rhs.id }

    public func hash(into hasher: inout Hasher) { hasher.combine(id) }
}

extension Budget {
    public static func make(
        periodStart: Date,
        income: Decimal,
        method: BudgetMethod,
        buckets: [BudgetBucket]? = nil,
        calendar: Calendar = .current
    ) -> Budget {
        let monthStart = calendar.startOfMonth(for: periodStart)
        let budget = Budget(periodStart: monthStart, income: income, method: method)
        
        for bucket in buckets ?? method.generateBucketByIncome(income) {
            let allocation = BudgetAllocation(budget: budget, kind: bucket.kind, ratio: bucket.ratio, targetAmount: bucket.amount)
            budget.allocations.append(allocation)
        }
        return budget
    }
    
    public func copyFixedExpensePlans(from sourceBudget: Budget) {
        guard let destination = allocations.first(where: { $0.kind.supportsFixedExpensePlan }) else { return }
        for plan in sourceBudget.fixedExpensePlans {
            let newPlan = FixedExpensePlan(budget: self, allocation: destination, name: plan.name, amount: plan.amount, amountType: plan.amountType)
            fixedExpensePlans.append(newPlan)
            destination.fixedExpensePlans.append(newPlan)
        }
    }
    
    public func actualAmount(for allocation: BudgetAllocation) -> Decimal {
        allocation.transactions.reduce(Decimal.zero) { $0 + $1.amount }
    }
    
    public func allocation(for transaction: BudgetTransaction) -> BudgetAllocation? {
        allocations.first { $0.id == transaction.allocation?.id }
    }
    
    public func transactions(for allocation: BudgetAllocation) -> [BudgetTransaction] {
        allocation.transactions
    }
    
    public func fixedExpensePlans(for allocation: BudgetAllocation) -> [FixedExpensePlan] {
        guard allocation.kind.supportsFixedExpensePlan else { return [] }
        return allocation.fixedExpensePlans
    }
    
    public func status(for allocation: BudgetAllocation) -> BudgetAllocationStatus {
        let actualAmount = actualAmount(for: allocation)
        let remainingAmount = allocation.targetAmount - actualAmount
        
        if allocation.kind.isSavingsLike {
            return actualAmount >= allocation.targetAmount ? .done : .needMore
        }
        
        return remainingAmount >= 0 ? .ok : .over
    }
    
    public func remainingAmount(for allocation: BudgetAllocation) -> Decimal {
        allocation.targetAmount - actualAmount(for: allocation)
    }

    /// The amount that can still be used in an allocation after deficits from
    /// over-target allocations have been covered by the rest of the budget.
    ///
    /// Deficits are distributed proportionally across allocations that still
    /// have a positive planned balance. This keeps the sum of available amounts
    /// aligned with the money that is actually left in the monthly budget.
    public func availableAmount(for allocation: BudgetAllocation) -> Decimal {
        let plannedRemaining = remainingAmount(for: allocation)
        guard plannedRemaining > 0 else { return plannedRemaining }

        let deficit = allocations.reduce(Decimal.zero) { result, allocation in
            let remaining = remainingAmount(for: allocation)
            return result + (remaining < 0 ? -remaining : .zero)
        }
        guard deficit > 0 else { return plannedRemaining }

        let totalPositiveRemaining = allocations.reduce(Decimal.zero) { result, allocation in
            let remaining = remainingAmount(for: allocation)
            return result + max(remaining, .zero)
        }
        guard totalPositiveRemaining > 0 else { return .zero }

        let coveredDeficit = min(deficit, totalPositiveRemaining)
        let deficitShare = coveredDeficit * plannedRemaining / totalPositiveRemaining
        return max(plannedRemaining - deficitShare, .zero)
    }
    
    public func barProgress(for allocation: BudgetAllocation) -> Decimal {
        guard allocation.targetAmount > 0 else {
            if allocation.kind.isSavingsLike {
                return actualAmount(for: allocation) > 0 ? 1 : .zero
            }
            
            return remainingAmount(for: allocation) > 0 ? 1 : .zero
        }
        
        if allocation.kind.isSavingsLike {
            return actualAmount(for: allocation) / allocation.targetAmount
        }
        
        return availableAmount(for: allocation) / allocation.targetAmount
    }
    
    public func actualRatio(for allocation: BudgetAllocation) -> Decimal {
        guard income > 0 else { return .zero }
        return actualAmount(for: allocation) / income
    }
    
    public func allocationSummary(for allocation: BudgetAllocation) -> BudgetAllocationSummary {
        let actualAmount = actualAmount(for: allocation)
        let remainingAmount = availableAmount(for: allocation)
        let barProgress = barProgress(for: allocation)
        
        return BudgetAllocationSummary(
            allocation: allocation,
            actualAmount: actualAmount,
            remainingAmount: remainingAmount,
            status: status(for: allocation),
            planRatio: allocation.ratio,
            actualRatio: actualRatio(for: allocation),
            barProgress: barProgress,
            displayBarProgress: min(max(barProgress.doubleValue, 0), 1)
        )
    }
    
}
