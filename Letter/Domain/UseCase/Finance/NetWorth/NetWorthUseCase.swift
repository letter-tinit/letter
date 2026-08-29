import Foundation

protocol NetWorthUseCase {
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
    func save() throws
}

final class ImpNetWorthUseCase: NetWorthUseCase {
    private let repository: any NetWorthRepository

    init(repository: any NetWorthRepository) {
        self.repository = repository
    }

    func createSnapshot(for month: Date, calendar: Calendar) throws {
        try repository.addSnapshot(
            NetWorthSnapshot(asOfDate: calendar.startOfMonth(for: month))
        )
    }

    func addItem(
        _ input: ValidatedNetWorthItemInput,
        to snapshot: NetWorthSnapshot,
        existingItems: [NetWorthPlanItem]
    ) throws {
        let item = NetWorthPlanItem(
            category: input.category,
            name: input.name,
            displayOrder: nextOrder(for: input.category, in: existingItems)
        )
        try repository.addPlanItem(item)
        snapshot.setAmount(input.amount, for: item)
        try repository.save()
    }

    func updateItem(
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
        try repository.save()
    }

    func deleteItem(_ item: NetWorthPlanItem) throws {
        try repository.removePlanItem(item)
    }

    func toggleEditingLock(for snapshot: NetWorthSnapshot) throws {
        snapshot.isLocked.toggle()
        try repository.save()
    }

    func deleteSnapshot(_ snapshot: NetWorthSnapshot) throws {
        try repository.removeSnapshot(snapshot)
    }

    func save() throws {
        try repository.save()
    }

    private func nextOrder(
        for category: NetWorthCategory,
        in items: [NetWorthPlanItem]
    ) -> Int {
        (items.filter { $0.category == category }.map(\.displayOrder).max() ?? 0) + 1
    }
}
