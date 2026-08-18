//
//  Budget.swift
//  Personal Finance
//
//  Created by TiniT on 13/7/26.
//
import Foundation
import SwiftData

enum BudgetError: LocalizedError {
    case invalidAmount
    case invalidTransactionType
    case allocationNotFound
    case transactionNotFound
    case fixedExpensePlanNotFound
    case fixedExpensePlanAlreadyCompleted
    case invalidFixedExpensePlanAmount
    case unsupportedFixedExpensePlanAllocation
    case duplicatePeriod
    
    var errorDescription: String? {
        switch self {
        case .invalidAmount: "transaction.form.error.amount.positive".localized
        case .invalidTransactionType: "transaction.form.error.description".localized
        case .allocationNotFound: "transaction.form.error.allocation".localized
        case .transactionNotFound: "transaction.form.error.delete".localized
        case .fixedExpensePlanNotFound: "fixed.plan.form.error.delete".localized
        case .fixedExpensePlanAlreadyCompleted: "fixed.plan.form.error.save".localized
        case .invalidFixedExpensePlanAmount: "fixed.plan.form.error.amount".localized
        case .unsupportedFixedExpensePlanAllocation: "fixed.plan.form.error.save".localized
        case .duplicatePeriod: "budget.create.error.duplicatePeriod".localized
        }
    }
}

@Model
final class Budget: Identifiable {
    @Attribute(.unique) var id: UUID = UUID()
    var periodStart: Date = Date()
    var income: Decimal = 0
    var lockAt: Date?
    var method: BudgetMethod = BudgetMethod.fiftyThirtyTwenty
    var createdAt: Date = Date()
    
    @Relationship(deleteRule: .cascade, inverse: \BudgetAllocation.budget)
    var allocations: [BudgetAllocation] = []
    
    @Relationship(deleteRule: .cascade, inverse: \FixedExpensePlan.budget)
    var fixedExpensePlans: [FixedExpensePlan] = []
    
    @Relationship(deleteRule: .cascade, inverse: \BudgetTransaction.budget)
    var transactions: [BudgetTransaction] = []
    
    init(id: UUID = UUID(), periodStart: Date, income: Decimal, method: BudgetMethod, createdAt: Date = .now) {
        self.id = id
        self.periodStart = periodStart
        self.income = income
        self.method = method
        self.createdAt = createdAt
    }
}

@Model
final class BudgetTransaction: Identifiable {
    @Attribute(.unique) var id: UUID = UUID()
    var budget: Budget?
    var allocation: BudgetAllocation?
    var type: TransactionType = TransactionType.expense
    var title: String = ""
    var note: String = ""
    var occurredAt: Date = Date()
    var amount: Decimal = 0
    var paymentMethod: PaymentMethod = PaymentMethod.banking
    
    // inverse được suy ra từ FixedExpensePlan.transaction — KHÔNG khai báo @Relationship ở đây
    var fixedExpensePlan: FixedExpensePlan?
    
    init(id: UUID = UUID(), budget: Budget? = nil, allocation: BudgetAllocation? = nil, type: TransactionType = .expense, title: String, note: String = "", occurredAt: Date = .now, amount: Decimal, paymentMethod: PaymentMethod) {
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
}

extension Budget {
    var name: String {
        Calendar.current.startOfMonth(for: periodStart).toString(withFormat: .month)
    }
    
    var isLocked: Bool {
        lockAt != nil
    }
    
    static func make(
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
    
    func copyFixedExpensePlans(from sourceBudget: Budget) {
        guard let destination = allocations.first(where: { $0.kind.supportsFixedExpensePlan }) else { return }
        for plan in sourceBudget.fixedExpensePlans {
            let newPlan = FixedExpensePlan(budget: self, allocation: destination, name: plan.name, amount: plan.amount, amountType: plan.amountType)
            fixedExpensePlans.append(newPlan)
        }
    }
    
    func actualAmount(for allocation: BudgetAllocation) -> Decimal {
        allocation.transactions.reduce(Decimal.zero) { $0 + $1.amount }
    }
    
    func allocation(for transaction: BudgetTransaction) -> BudgetAllocation? {
        allocations.first { $0.id == transaction.allocation?.id }
    }
    
    func transactions(for allocation: BudgetAllocation) -> [BudgetTransaction] {
        allocation.transactions
    }
    
    func fixedExpensePlans(for allocation: BudgetAllocation) -> [FixedExpensePlan] {
        guard allocation.kind.supportsFixedExpensePlan else { return [] }
        return allocation.fixedExpensePlans
    }
    
    func status(for allocation: BudgetAllocation) -> BudgetAllocationStatus {
        let actualAmount = actualAmount(for: allocation)
        let remainingAmount = allocation.targetAmount - actualAmount
        
        if allocation.kind.isSavingsLike {
            return actualAmount >= allocation.targetAmount ? .done : .needMore
        }
        
        return remainingAmount >= 0 ? .ok : .over
    }
    
    func remainingAmount(for allocation: BudgetAllocation) -> Decimal {
        allocation.targetAmount - actualAmount(for: allocation)
    }

    /// The amount that can still be used in an allocation after deficits from
    /// over-target allocations have been covered by the rest of the budget.
    ///
    /// Deficits are distributed proportionally across allocations that still
    /// have a positive planned balance. This keeps the sum of available amounts
    /// aligned with the money that is actually left in the monthly budget.
    func availableAmount(for allocation: BudgetAllocation) -> Decimal {
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
    
    func barProgress(for allocation: BudgetAllocation) -> Decimal {
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
    
    func actualRatio(for allocation: BudgetAllocation) -> Decimal {
        guard income > 0 else { return .zero }
        return actualAmount(for: allocation) / income
    }
    
    func allocationSummary(for allocation: BudgetAllocation) -> BudgetAllocationSummary {
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
    
    func carryoverAmount() -> Decimal {
        allocations.reduce(.zero) { result, allocation in
            result + remainingAmount(for: allocation)
        }
    }
}
