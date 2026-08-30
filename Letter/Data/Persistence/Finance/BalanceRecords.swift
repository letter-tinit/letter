import Foundation
import SwiftData

@Model
final class TransactionRecord {
    @Attribute(.unique) var id: UUID
    var note: String?
    var type: TransactionType
    var category: TransactionCategory
    var method: PaymentMethod
    var amount: Decimal
    var occurredAt: Date
    var createAt: Date

    init(
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
final class BalanceMonthRecord {
    @Attribute(.unique) var id: Date
    var monthStart: Date
    var isLocked: Bool

    init(monthStart: Date, isLocked: Bool) {
        let normalized = Calendar.current.startOfMonth(for: monthStart)
        self.id = normalized
        self.monthStart = normalized
        self.isLocked = isLocked
    }
}
