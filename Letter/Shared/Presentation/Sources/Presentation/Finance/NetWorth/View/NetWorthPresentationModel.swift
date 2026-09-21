import Foundation
import Observation
import Domain

@Observable
public final class NetWorthItemPresentationModel: Identifiable {
    public let id: UUID
    public var category: NetWorthCategory
    public var name: String
    public var displayOrder: Int
    public var amount: Decimal?

    public init(
        item: NetWorthPlanItem,
        amount: Decimal?
    ) {
        id = item.id
        category = item.category
        name = item.name
        displayOrder = item.displayOrder
        self.amount = amount
    }
}

@Observable
public final class NetWorthPresentationModel {
    public let snapshotID: UUID
    public let asOfDate: Date
    public var isEditingUnlocked: Bool
    public var items: [NetWorthItemPresentationModel]

    public init(
        snapshot: NetWorthSnapshot,
        planItems: [NetWorthPlanItem]
    ) {
        snapshotID = snapshot.id
        asOfDate = snapshot.asOfDate
        isEditingUnlocked = !snapshot.isLocked
        items = planItems
            .sorted { $0.displayOrder < $1.displayOrder }
            .map { item in
                NetWorthItemPresentationModel(
                    item: item,
                    amount: snapshot.amount(for: item)
                )
            }
    }

    public var totalAssets: Decimal {
        total(for: .assets)
    }

    public var totalLiabilities: Decimal {
        total(for: .liabilities)
    }

    public var netWorth: Decimal {
        totalAssets - totalLiabilities
    }

    public var missingValueCount: Int {
        items.filter { $0.amount == nil }.count
    }

    public func items(in category: NetWorthCategory) -> [NetWorthItemPresentationModel] {
        items
            .filter { $0.category == category }
            .sorted { $0.displayOrder < $1.displayOrder }
    }

    public func subtotal(for category: NetWorthCategory) -> Decimal {
        items(in: category)
            .compactMap(\.amount)
            .reduce(.zero, +)
    }

    public func total(for group: NetWorthGroup) -> Decimal {
        items
            .filter { $0.category.group == group }
            .compactMap(\.amount)
            .reduce(.zero, +)
    }
}
