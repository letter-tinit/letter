import Foundation
import Domain
import Utility
import Styleguide

@Observable
@MainActor
public final class NetWorthViewModel {
    private let useCase: any NetWorthUseCase
    public var toastMessage: ToastMessage?
    public var snapshots: [NetWorthSnapshot] = []
    public var planItems: [NetWorthPlanItem] = []

    public init(useCase: any NetWorthUseCase) {
        self.useCase = useCase
        load()
    }

    public func load() {
        do {
            let data = try useCase.load()
            snapshots = data.snapshots
            planItems = data.planItems
        } catch {
            showError(error.localizedDescription)
        }
    }

    public func createSnapshot(for month: Date) {
        do {
            try useCase.createSnapshot(for: month, calendar: .current)
            load()
        } catch {
            showError(error.localizedDescription)
        }
    }

    public func addItem(
        _ input: ValidatedNetWorthItemInput,
        to snapshot: NetWorthSnapshot,
        existingItems: [NetWorthPlanItem]
    ) throws {
        try useCase.addItem(input, to: snapshot, existingItems: existingItems)
        load()
    }

    public func updateItem(
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
        load()
    }

    public func deleteItem(_ item: NetWorthPlanItem) throws {
        try useCase.deleteItem(item)
        load()
    }

    public func toggleEditingLock(for snapshot: NetWorthSnapshot) {
        do {
            try useCase.toggleEditingLock(for: snapshot)
            load()
        } catch {
            showError(error.localizedDescription)
        }
    }

    public func deleteSnapshot(_ snapshot: NetWorthSnapshot) {
        do {
            try useCase.deleteSnapshot(snapshot)
            load()
        } catch {
            showError(error.localizedDescription)
        }
    }

    private func showError(_ text: String) {
        toastMessage = ToastMessage(text: text, type: .failure)
    }
}
