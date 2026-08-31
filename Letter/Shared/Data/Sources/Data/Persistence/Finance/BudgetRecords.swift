import Foundation
import SwiftData
import Domain
import Core
import Utility

@Model
public final class BudgetRecord {
    @Attribute(.unique) public var id: UUID
    public var periodStart: Date
    public var income: Decimal
    public var isLocked: Bool
    public var method: BudgetMethod
    public var createdAt: Date

    @Relationship(deleteRule: .cascade, inverse: \BudgetAllocationRecord.budget)
    public var allocations: [BudgetAllocationRecord] = []
    @Relationship(deleteRule: .cascade, inverse: \FixedExpensePlanRecord.budget)
    public var fixedExpensePlans: [FixedExpensePlanRecord] = []
    @Relationship(deleteRule: .cascade, inverse: \BudgetTransactionRecord.budget)
    public var transactions: [BudgetTransactionRecord] = []

    public init(id: UUID, periodStart: Date, income: Decimal, isLocked: Bool, method: BudgetMethod, createdAt: Date) {
        self.id = id
        self.periodStart = periodStart
        self.income = income
        self.isLocked = isLocked
        self.method = method
        self.createdAt = createdAt
    }
}

@Model
public final class BudgetAllocationRecord {
    @Attribute(.unique) public var id: UUID
    public var budget: BudgetRecord?
    public var kind: BudgetBucketKind
    public var ratio: Decimal
    public var targetAmount: Decimal

    @Relationship(deleteRule: .cascade, inverse: \BudgetTransactionRecord.allocation)
    public var transactions: [BudgetTransactionRecord] = []
    @Relationship(deleteRule: .cascade, inverse: \FixedExpensePlanRecord.allocation)
    public var fixedExpensePlans: [FixedExpensePlanRecord] = []

    public init(id: UUID, kind: BudgetBucketKind, ratio: Decimal, targetAmount: Decimal) {
        self.id = id
        self.kind = kind
        self.ratio = ratio
        self.targetAmount = targetAmount
    }
}

@Model
public final class BudgetTransactionRecord {
    @Attribute(.unique) public var id: UUID
    public var budget: BudgetRecord?
    public var allocation: BudgetAllocationRecord?
    public var type: TransactionType
    public var title: String
    public var note: String
    public var occurredAt: Date
    public var amount: Decimal
    public var paymentMethod: PaymentMethod
    public var fixedExpensePlan: FixedExpensePlanRecord?

    public init(
        id: UUID,
        type: TransactionType,
        title: String,
        note: String,
        occurredAt: Date,
        amount: Decimal,
        paymentMethod: PaymentMethod
    ) {
        self.id = id
        self.type = type
        self.title = title
        self.note = note
        self.occurredAt = occurredAt
        self.amount = amount
        self.paymentMethod = paymentMethod
    }
}

@Model
public final class FixedExpensePlanRecord {
    @Attribute(.unique) public var id: UUID
    public var budget: BudgetRecord?
    public var allocation: BudgetAllocationRecord?
    public var name: String
    public var amount: Decimal
    public var amountType: FixedExpensePlanAmountType

    @Relationship(deleteRule: .nullify, inverse: \BudgetTransactionRecord.fixedExpensePlan)
    public var transaction: BudgetTransactionRecord?

    public init(id: UUID, name: String, amount: Decimal, amountType: FixedExpensePlanAmountType) {
        self.id = id
        self.name = name
        self.amount = amount
        self.amountType = amountType
    }
}
