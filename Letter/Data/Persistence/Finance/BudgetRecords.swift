import Foundation
import SwiftData

@Model
final class BudgetRecord {
    @Attribute(.unique) var id: UUID
    var periodStart: Date
    var income: Decimal
    var isLocked: Bool
    var method: BudgetMethod
    var createdAt: Date

    @Relationship(deleteRule: .cascade, inverse: \BudgetAllocationRecord.budget)
    var allocations: [BudgetAllocationRecord] = []
    @Relationship(deleteRule: .cascade, inverse: \FixedExpensePlanRecord.budget)
    var fixedExpensePlans: [FixedExpensePlanRecord] = []
    @Relationship(deleteRule: .cascade, inverse: \BudgetTransactionRecord.budget)
    var transactions: [BudgetTransactionRecord] = []

    init(id: UUID, periodStart: Date, income: Decimal, isLocked: Bool, method: BudgetMethod, createdAt: Date) {
        self.id = id
        self.periodStart = periodStart
        self.income = income
        self.isLocked = isLocked
        self.method = method
        self.createdAt = createdAt
    }
}

@Model
final class BudgetAllocationRecord {
    @Attribute(.unique) var id: UUID
    var budget: BudgetRecord?
    var kind: BudgetBucketKind
    var ratio: Decimal
    var targetAmount: Decimal

    @Relationship(deleteRule: .cascade, inverse: \BudgetTransactionRecord.allocation)
    var transactions: [BudgetTransactionRecord] = []
    @Relationship(deleteRule: .cascade, inverse: \FixedExpensePlanRecord.allocation)
    var fixedExpensePlans: [FixedExpensePlanRecord] = []

    init(id: UUID, kind: BudgetBucketKind, ratio: Decimal, targetAmount: Decimal) {
        self.id = id
        self.kind = kind
        self.ratio = ratio
        self.targetAmount = targetAmount
    }
}

@Model
final class BudgetTransactionRecord {
    @Attribute(.unique) var id: UUID
    var budget: BudgetRecord?
    var allocation: BudgetAllocationRecord?
    var type: TransactionType
    var title: String
    var note: String
    var occurredAt: Date
    var amount: Decimal
    var paymentMethod: PaymentMethod
    var fixedExpensePlan: FixedExpensePlanRecord?

    init(
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
final class FixedExpensePlanRecord {
    @Attribute(.unique) var id: UUID
    var budget: BudgetRecord?
    var allocation: BudgetAllocationRecord?
    var name: String
    var amount: Decimal
    var amountType: FixedExpensePlanAmountType

    @Relationship(deleteRule: .nullify, inverse: \BudgetTransactionRecord.fixedExpensePlan)
    var transaction: BudgetTransactionRecord?

    init(id: UUID, name: String, amount: Decimal, amountType: FixedExpensePlanAmountType) {
        self.id = id
        self.name = name
        self.amount = amount
        self.amountType = amountType
    }
}
