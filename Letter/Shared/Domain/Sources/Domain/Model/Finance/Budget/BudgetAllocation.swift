//
//  BudgetAllocation.swift
//  Letter
//
//  Created by TiniT on 24/7/26.
//

import Foundation
import Utility

public final class BudgetAllocation: Identifiable, Hashable {
    public var id: UUID = UUID()
    public var budget: Budget?
    public var kind: BudgetBucketKind = BudgetBucketKind.needs
    public var ratio: Decimal = 0
    public var targetAmount: Decimal = 0

    public var transactions: [BudgetTransaction] = []

    public var fixedExpensePlans: [FixedExpensePlan] = []

    public init(id: UUID = UUID(), budget: Budget? = nil, kind: BudgetBucketKind, ratio: Decimal, targetAmount: Decimal) {
        self.id = id
        self.budget = budget
        self.kind = kind
        self.ratio = ratio
        self.targetAmount = targetAmount
    }

    public static func == (lhs: BudgetAllocation, rhs: BudgetAllocation) -> Bool { lhs.id == rhs.id }

    public func hash(into hasher: inout Hasher) { hasher.combine(id) }
}

public extension BudgetAllocation {
    public var expectedTransactionType: TransactionType {
        kind.isSavingsLike ? .income : .expense
    }
}

public enum BudgetAllocationStatus: Hashable {
    case done, needMore, ok, over
    public var localizationKey: String {
        switch self {
        case .ok: "budget.status.ok"
        case .over: "budget.status.over"
        case .done: "budget.status.done"
        case .needMore: "budget.status.needMore"
        }
    }
    
    public var systemImageName: String {
        switch self {
        case .ok, .done: "checkmark.circle.fill"
        case .over: "exclamationmark.circle.fill"
        case .needMore: "circle"
        }
    }
}

public struct BudgetAllocationSummary: Hashable {
    public let allocation: BudgetAllocation
    public let actualAmount: Decimal
    public let remainingAmount: Decimal
    public let status: BudgetAllocationStatus
    public let planRatio: Decimal
    public let actualRatio: Decimal
    public let barProgress: Decimal
    public let displayBarProgress: Double
}
