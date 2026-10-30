import Foundation
import SwiftData
import Domain

@Model
public final class BudgetRecord {
    @Attribute(.unique) public var id: UUID
    public var month: Date
    public var createdAt: Date?
    public var isLocked: Bool
    public var incomeAmount: Decimal
    public var pyfAmount: Decimal
    @Relationship(deleteRule: .cascade, inverse: \BudgetTransactionRecord.budget)
    public var transactions: [BudgetTransactionRecord]

    public init(id: UUID, month: Date, createdAt: Date? = nil, isLocked: Bool, incomeAmount: Decimal, pyfAmount: Decimal, transactions: [BudgetTransactionRecord] = []) {
        self.id = id
        self.month = month
        self.createdAt = createdAt
        self.isLocked = isLocked
        self.incomeAmount = incomeAmount
        self.pyfAmount = pyfAmount
        self.transactions = transactions
    }
}

@Model
public final class BudgetTransactionRecord {
    @Attribute(.unique) public var id: UUID
    public var amount: Decimal
    public var transactionDescription: String
    public var date: Date
    public var categoryRawValue: String
    public var fixedPlanID: UUID?
    public var budget: BudgetRecord?

    public init(id: UUID, amount: Decimal, description: String, date: Date, categoryRawValue: String, fixedPlanID: UUID? = nil) {
        self.id = id
        self.amount = amount
        self.transactionDescription = description
        self.date = date
        self.categoryRawValue = categoryRawValue
        self.fixedPlanID = fixedPlanID
    }
}

@Model
public final class BudgetFixedPlanRecord {
    @Attribute(.unique) public var id: UUID
    public var planDescription: String
    public var amount: Decimal
    public var categoryRawValue: String

    public init(id: UUID, description: String, amount: Decimal, categoryRawValue: String) {
        self.id = id
        self.planDescription = description
        self.amount = amount
        self.categoryRawValue = categoryRawValue
    }

    func toDomain() -> BudgetFixedPlan {
        BudgetFixedPlan(id: id, description: planDescription, amount: amount,
                        category: BudgetTransactionCategory(rawValue: categoryRawValue) ?? .other)
    }
}

@Model
public final class BudgetCycleSettingsRecord {
    @Attribute(.unique) public var id: String
    public var day: Int

    public init(id: String = "global", day: Int) {
        self.id = id
        self.day = min(28, max(1, day))
    }
}

extension BudgetRecord {
    func toDomain() -> Budget {
        let creationDate = createdAt ?? month
        return Budget(id: id, month: month, createdAt: creationDate,
                      isLocked: isLocked, incomeAmount: incomeAmount, pyfAmount: pyfAmount,
                      transactions: transactions.map { $0.toDomain() })
    }
}

extension BudgetTransactionRecord {
    func toDomain() -> BudgetTransaction {
        BudgetTransaction(id: id, amount: amount, description: transactionDescription, date: date,
                          category: BudgetTransactionCategory(rawValue: categoryRawValue) ?? .other,
                          fixedPlanID: fixedPlanID)
    }
}
