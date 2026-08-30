import Foundation
import SwiftData

@Model
final class NetWorthPlanItemRecord {
    @Attribute(.unique) var id: UUID
    var category: NetWorthCategory
    var name: String
    var displayOrder: Int

    @Relationship(deleteRule: .cascade, inverse: \NetWorthValueRecord.planItem)
    var values: [NetWorthValueRecord] = []

    init(id: UUID, category: NetWorthCategory, name: String, displayOrder: Int) {
        self.id = id
        self.category = category
        self.name = name
        self.displayOrder = displayOrder
    }
}

@Model
final class NetWorthValueRecord {
    @Attribute(.unique) var id: UUID
    var amount: Decimal?
    var planItem: NetWorthPlanItemRecord?
    var snapshot: NetWorthSnapshotRecord?

    init(id: UUID, amount: Decimal?) {
        self.id = id
        self.amount = amount
    }
}

@Model
final class NetWorthSnapshotRecord {
    @Attribute(.unique) var id: UUID
    var asOfDate: Date
    var isLocked: Bool

    @Relationship(deleteRule: .cascade, inverse: \NetWorthValueRecord.snapshot)
    var values: [NetWorthValueRecord] = []

    init(id: UUID, asOfDate: Date, isLocked: Bool) {
        self.id = id
        self.asOfDate = asOfDate
        self.isLocked = isLocked
    }
}
