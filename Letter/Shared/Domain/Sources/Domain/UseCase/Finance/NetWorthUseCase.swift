import Foundation
import Utility

@MainActor
public protocol NetWorthUseCase {
    func load() throws -> NetWorthData
    func createSnapshot(for month: Date, calendar: Calendar) throws
    func addItem(
        _ input: ValidatedNetWorthItemInput,
        to snapshot: NetWorthSnapshot,
        existingItems: [NetWorthPlanItem]
    ) throws
    func updateItem(
        _ item: NetWorthPlanItem,
        input: ValidatedNetWorthItemInput,
        snapshot: NetWorthSnapshot,
        existingItems: [NetWorthPlanItem]
    ) throws
    func deleteItem(_ item: NetWorthPlanItem) throws
    func toggleEditingLock(for snapshot: NetWorthSnapshot) throws
    func deleteSnapshot(_ snapshot: NetWorthSnapshot) throws
}

@MainActor
public final class ImpNetWorthUseCase: NetWorthUseCase {
    private let repository: any NetWorthRepository

    public init(repository: any NetWorthRepository) {
        self.repository = repository
    }

    public func load() throws -> NetWorthData {
        try repository.fetchData()
    }

    public func createSnapshot(for month: Date, calendar: Calendar) throws {
        try repository.saveSnapshot(
            NetWorthSnapshot(asOfDate: calendar.startOfMonth(for: month))
        )
    }

    public func addItem(
        _ input: ValidatedNetWorthItemInput,
        to snapshot: NetWorthSnapshot,
        existingItems: [NetWorthPlanItem]
    ) throws {
        let item = NetWorthPlanItem(
            category: input.category,
            name: input.name,
            displayOrder: nextOrder(for: input.category, in: existingItems)
        )
        try repository.savePlanItem(item)
        snapshot.setAmount(input.amount, for: item)
        try repository.saveSnapshot(snapshot)
    }

    public func updateItem(
        _ item: NetWorthPlanItem,
        input: ValidatedNetWorthItemInput,
        snapshot: NetWorthSnapshot,
        existingItems: [NetWorthPlanItem]
    ) throws {
        if item.category != input.category {
            item.displayOrder = nextOrder(for: input.category, in: existingItems)
        }
        item.category = input.category
        item.name = input.name
        snapshot.setAmount(input.amount, for: item)
        try repository.savePlanItem(item)
        try repository.saveSnapshot(snapshot)
    }

    public func deleteItem(_ item: NetWorthPlanItem) throws {
        try repository.deletePlanItem(id: item.id)
    }

    public func toggleEditingLock(for snapshot: NetWorthSnapshot) throws {
        snapshot.isLocked.toggle()
        try repository.saveSnapshot(snapshot)
    }

    public func deleteSnapshot(_ snapshot: NetWorthSnapshot) throws {
        try repository.deleteSnapshot(id: snapshot.id)
    }

    private func nextOrder(
        for category: NetWorthCategory,
        in items: [NetWorthPlanItem]
    ) -> Int {
        (items.filter { $0.category == category }.map(\.displayOrder).max() ?? 0) + 1
    }
}
