//
//  BudgetAllocation.swift
//  Personal Finance
//
//  Created by TiniT on 24/7/26.
//

import SwiftData
import Foundation

@Model
final class BudgetAllocation: Identifiable {
    @Attribute(.unique) var id: UUID = UUID()
    var budget: Budget?
    var kind: BudgetBucketKind = BudgetBucketKind.needs
    var ratio: Decimal = 0
    var targetAmount: Decimal = 0

    @Relationship(deleteRule: .cascade, inverse: \BudgetTransaction.allocation)
    var transactions: [BudgetTransaction] = []

    @Relationship(deleteRule: .cascade, inverse: \FixedExpensePlan.allocation)
    var fixedExpensePlans: [FixedExpensePlan] = []

    init(id: UUID = UUID(), budget: Budget? = nil, kind: BudgetBucketKind, ratio: Decimal, targetAmount: Decimal) {
        self.id = id
        self.budget = budget
        self.kind = kind
        self.ratio = ratio
        self.targetAmount = targetAmount
    }
}

extension BudgetAllocation {
    var expectedTransactionType: TransactionType {
        kind.isSavingsLike ? .income : .expense
    }
}

enum BudgetAllocationStatus: Hashable {
    case done, needMore, ok, over
    var localizationKey: String {
        switch self {
        case .ok: "budget.status.ok"
        case .over: "budget.status.over"
        case .done: "budget.status.done"
        case .needMore: "budget.status.needMore"
        }
    }
    
    var systemImageName: String {
        switch self {
        case .ok, .done: "checkmark.circle.fill"
        case .over: "exclamationmark.circle.fill"
        case .needMore: "circle"
        }
    }
}

struct BudgetAllocationSummary: Hashable {
    let allocation: BudgetAllocation
    let actualAmount: Decimal
    let remainingAmount: Decimal
    let status: BudgetAllocationStatus
    let planRatio: Decimal
    let actualRatio: Decimal
    let barProgress: Decimal
    let displayBarProgress: Double
}
