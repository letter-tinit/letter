import Foundation
import SwiftData
import Domain
import Utility

@Model
public final class NetWorthPlanItemRecord {
    @Attribute(.unique) public var id: UUID
    public var category: NetWorthCategory
    public var name: String
    public var displayOrder: Int

    @Relationship(deleteRule: .cascade, inverse: \NetWorthValueRecord.planItem)
    public var values: [NetWorthValueRecord] = []

    public init(id: UUID, category: NetWorthCategory, name: String, displayOrder: Int) {
        self.id = id
        self.category = category
        self.name = name
        self.displayOrder = displayOrder
    }
}

@Model
public final class NetWorthValueRecord {
    @Attribute(.unique) public var id: UUID
    public var amount: Decimal?
    public var planItem: NetWorthPlanItemRecord?
    public var snapshot: NetWorthSnapshotRecord?

    public init(id: UUID, amount: Decimal?) {
        self.id = id
        self.amount = amount
    }
}

@Model
public final class NetWorthSnapshotRecord {
    @Attribute(.unique) public var id: UUID
    public var asOfDate: Date
    public var isLocked: Bool

    @Relationship(deleteRule: .cascade, inverse: \NetWorthValueRecord.snapshot)
    public var values: [NetWorthValueRecord] = []

    public init(id: UUID, asOfDate: Date, isLocked: Bool) {
        self.id = id
        self.asOfDate = asOfDate
        self.isLocked = isLocked
    }
}
