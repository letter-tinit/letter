import Foundation
import SwiftData
import Domain
import Utility

@Model
public final class TransactionRecord {
    @Attribute(.unique) public var id: UUID
    public var note: String?
    public var type: TransactionType
    public var category: TransactionCategory
    public var method: PaymentMethod
    public var amount: Decimal
    public var occurredAt: Date
    public var createAt: Date

    public init(
        id: UUID,
        note: String?,
        type: TransactionType,
        category: TransactionCategory,
        method: PaymentMethod,
        amount: Decimal,
        occurredAt: Date,
        createAt: Date
    ) {
        self.id = id
        self.note = note
        self.type = type
        self.category = category
        self.method = method
        self.amount = amount
        self.occurredAt = occurredAt
        self.createAt = createAt
    }
}

@Model
public final class BalanceMonthRecord {
    @Attribute(.unique) public var id: Date
    public var monthStart: Date
    public var isLocked: Bool

    public init(monthStart: Date, isLocked: Bool) {
        let normalized = Calendar.current.startOfMonth(for: monthStart)
        self.id = normalized
        self.monthStart = normalized
        self.isLocked = isLocked
    }
}
