import Foundation

@Observable
final class NetWorthViewModel {
    private let repository: NetWorthRepository
    var toastMessage: ToastMessage?

    init(repository: NetWorthRepository) {
        self.repository = repository
    }

    func createSnapshot(for month: Date) {
        do {
            try repository.addSnapshot(
                NetWorthSnapshot(asOfDate: Calendar.current.startOfMonth(for: month))
            )
        } catch {
            showError(error.localizedDescription)
        }
    }

    func addItem(
        _ input: ValidatedNetWorthItemInput,
        to snapshot: NetWorthSnapshot,
        existingItems: [NetWorthPlanItem]
    ) throws {
        let order = existingItems
            .filter { $0.category == input.category }
            .map(\.displayOrder)
            .max() ?? 0
        let item = NetWorthPlanItem(
            category: input.category,
            name: input.name,
            displayOrder: order + 1
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
            item.displayOrder = (existingItems
                .filter { $0.category == input.category }
                .map(\.displayOrder)
                .max() ?? 0) + 1
        }
        item.category = input.category
        item.name = input.name
        snapshot.setAmount(input.amount, for: item)
        try repository.save()
    }

    func deleteItem(_ item: NetWorthPlanItem) throws {
        try repository.removePlanItem(item)
    }

    func save() {
        do {
            try repository.save()
        } catch {
            showError(error.localizedDescription)
        }
    }

    private func showError(_ text: String) {
        toastMessage = ToastMessage(text: text, type: .failure)
    }
}
