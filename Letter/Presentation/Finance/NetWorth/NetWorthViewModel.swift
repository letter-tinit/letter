import Foundation

@Observable
final class NetWorthViewModel {
    private let useCase: any NetWorthUseCase
    var toastMessage: ToastMessage?

    init(useCase: any NetWorthUseCase) {
        self.useCase = useCase
    }

    func createSnapshot(for month: Date) {
        do {
            try useCase.createSnapshot(for: month, calendar: .current)
        } catch {
            showError(error.localizedDescription)
        }
    }

    func addItem(
        _ input: ValidatedNetWorthItemInput,
        to snapshot: NetWorthSnapshot,
        existingItems: [NetWorthPlanItem]
    ) throws {
        try useCase.addItem(input, to: snapshot, existingItems: existingItems)
    }

    func updateItem(
        _ item: NetWorthPlanItem,
        input: ValidatedNetWorthItemInput,
        snapshot: NetWorthSnapshot,
        existingItems: [NetWorthPlanItem]
    ) throws {
        try useCase.updateItem(
            item,
            input: input,
            snapshot: snapshot,
            existingItems: existingItems
        )
    }

    func deleteItem(_ item: NetWorthPlanItem) throws {
        try useCase.deleteItem(item)
    }

    func toggleEditingLock(for snapshot: NetWorthSnapshot) {
        do {
            try useCase.toggleEditingLock(for: snapshot)
        } catch {
            showError(error.localizedDescription)
        }
    }

    func deleteSnapshot(_ snapshot: NetWorthSnapshot) {
        do {
            try useCase.deleteSnapshot(snapshot)
        } catch {
            showError(error.localizedDescription)
        }
    }

    func save() {
        do {
            try useCase.save()
        } catch {
            showError(error.localizedDescription)
        }
    }

    private func showError(_ text: String) {
        toastMessage = ToastMessage(text: text, type: .failure)
    }
}
