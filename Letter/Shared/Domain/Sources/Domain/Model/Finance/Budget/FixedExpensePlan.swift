//
//  FixedExpensePlan.swift
//  Letter
//
//  Created by TiniT on 24/7/26.
//

import Foundation
import Utility

public enum FixedExpensePlanAmountType: String, CaseIterable, Codable {
    case fixed
    case estimated
}

public final class FixedExpensePlan: Identifiable, Hashable {
    public var id: UUID = UUID()
    public var budget: Budget?
    public var allocation: BudgetAllocation?
    public var name: String = ""
    public var amount: Decimal = 0
    public var amountType: FixedExpensePlanAmountType = FixedExpensePlanAmountType.estimated
    
    public var transaction: BudgetTransaction?
    
    public init(id: UUID = UUID(), budget: Budget? = nil, allocation: BudgetAllocation? = nil, name: String, amount: Decimal, amountType: FixedExpensePlanAmountType = .estimated) {
        self.id = id
        self.budget = budget
        self.allocation = allocation
        self.name = name
        self.amount = amount
        self.amountType = amountType
    }

    public static func == (lhs: FixedExpensePlan, rhs: FixedExpensePlan) -> Bool { lhs.id == rhs.id }

    public func hash(into hasher: inout Hasher) { hasher.combine(id) }
}
