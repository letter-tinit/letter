import Foundation
import Utility

public struct ValidatedBudgetInput: Equatable {
    public let periodStart: Date
    public let income: Decimal
    public let method: BudgetMethod
    public let buckets: [BudgetBucket]
    public let reusesFixedExpensePlans: Bool
    public init(periodStart: Date, income: Decimal, method: BudgetMethod, buckets: [BudgetBucket], reusesFixedExpensePlans: Bool) { self.periodStart=periodStart; self.income=income; self.method=method; self.buckets=buckets; self.reusesFixedExpensePlans=reusesFixedExpensePlans }
}

public struct ValidatedBudgetTransactionInput: Equatable {
    public let description: String
    public let allocationID: UUID
    public let amount: Decimal
    public let occurredAt: Date
    public let paymentMethod: PaymentMethod
    public let note: String
    public init(description: String, allocationID: UUID, amount: Decimal, occurredAt: Date, paymentMethod: PaymentMethod, note: String) { self.description=description; self.allocationID=allocationID; self.amount=amount; self.occurredAt=occurredAt; self.paymentMethod=paymentMethod; self.note=note }
}

public struct ValidatedFixedExpensePlanInput: Equatable {
    public let name: String
    public let amount: Decimal
    public let amountType: FixedExpensePlanAmountType
    public init(name: String, amount: Decimal, amountType: FixedExpensePlanAmountType) { self.name=name; self.amount=amount; self.amountType=amountType }
}
