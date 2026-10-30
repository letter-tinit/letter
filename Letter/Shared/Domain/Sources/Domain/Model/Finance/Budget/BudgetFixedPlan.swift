import Foundation

public struct BudgetFixedPlan: Identifiable, Equatable {
    public let id: UUID
    public var description: String
    public var amount: Decimal
    public var category: BudgetTransactionCategory

    public init(id: UUID = UUID(), description: String, amount: Decimal, category: BudgetTransactionCategory) {
        self.id = id
        self.description = description
        self.amount = amount
        self.category = category
    }
}

public struct BudgetConfiguration: Equatable {
    public var fixedPlans: [BudgetFixedPlan]
    public var cycleDay: Int

    public init(fixedPlans: [BudgetFixedPlan] = [], cycleDay: Int) {
        self.fixedPlans = fixedPlans
        self.cycleDay = min(28, max(1, cycleDay))
    }
}
