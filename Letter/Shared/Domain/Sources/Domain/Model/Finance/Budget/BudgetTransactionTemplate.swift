import Foundation

public struct BudgetTransactionTemplate: Identifiable, Equatable {
    public let id: UUID
    public var description: String
    public var amount: Decimal?
    public var category: BudgetTransactionCategory

    public init(id: UUID = UUID(), description: String, amount: Decimal? = nil, category: BudgetTransactionCategory) {
        self.id = id
        self.description = description
        self.amount = amount
        self.category = category
    }
}

public struct BudgetConfiguration: Equatable {
    public var transactionTemplates: [BudgetTransactionTemplate]
    public var cycleDay: Int

    public init(transactionTemplates: [BudgetTransactionTemplate] = [], cycleDay: Int) {
        self.transactionTemplates = transactionTemplates
        self.cycleDay = min(28, max(1, cycleDay))
    }
}
