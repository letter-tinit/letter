//
//  FixedExpensePlan.swift
//  Letter
//
//  Created by TiniT on 24/7/26.
//

import Foundation

enum FixedExpensePlanAmountType: String, CaseIterable, Codable {
    case fixed
    case estimated
}

final class FixedExpensePlan: Identifiable, Hashable {
    var id: UUID = UUID()
    var budget: Budget?
    var allocation: BudgetAllocation?
    var name: String = ""
    var amount: Decimal = 0
    var amountType: FixedExpensePlanAmountType = FixedExpensePlanAmountType.estimated
    
    var transaction: BudgetTransaction?
    
    init(id: UUID = UUID(), budget: Budget? = nil, allocation: BudgetAllocation? = nil, name: String, amount: Decimal, amountType: FixedExpensePlanAmountType = .estimated) {
        self.id = id
        self.budget = budget
        self.allocation = allocation
        self.name = name
        self.amount = amount
        self.amountType = amountType
    }

    static func == (lhs: FixedExpensePlan, rhs: FixedExpensePlan) -> Bool { lhs.id == rhs.id }

    func hash(into hasher: inout Hasher) { hasher.combine(id) }
}
