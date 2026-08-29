import Foundation

struct ValidatedBudgetInput: Equatable {
    let periodStart: Date
    let income: Decimal
    let method: BudgetMethod
    let buckets: [BudgetBucket]
    let reusesFixedExpensePlans: Bool
}

struct ValidatedBudgetTransactionInput: Equatable {
    let description: String
    let allocationID: UUID
    let amount: Decimal
    let occurredAt: Date
    let paymentMethod: PaymentMethod
    let note: String
}

struct ValidatedFixedExpensePlanInput: Equatable {
    let name: String
    let amount: Decimal
    let amountType: FixedExpensePlanAmountType
}
