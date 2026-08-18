//
//  FixedExpensePlan.swift
//  Personal Finance
//
//  Created by TiniT on 24/7/26.
//

import SwiftData
import Foundation

enum FixedExpensePlanAmountType: String, CaseIterable, Codable {
    case fixed
    case estimated
}

@Model
final class FixedExpensePlan: Identifiable {
    @Attribute(.unique) var id: UUID = UUID()
    var budget: Budget?
    var allocation: BudgetAllocation?
    var name: String = ""
    var amount: Decimal = 0
    var amountType: FixedExpensePlanAmountType = FixedExpensePlanAmountType.estimated
    
    @Relationship(deleteRule: .nullify, inverse: \BudgetTransaction.fixedExpensePlan)
    var transaction: BudgetTransaction?
    
    init(id: UUID = UUID(), budget: Budget? = nil, allocation: BudgetAllocation? = nil, name: String, amount: Decimal, amountType: FixedExpensePlanAmountType = .estimated) {
        self.id = id
        self.budget = budget
        self.allocation = allocation
        self.name = name
        self.amount = amount
        self.amountType = amountType
    }
}
