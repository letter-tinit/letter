import Foundation
import Domain
import Utility
import Styleguide

@Observable
@MainActor
public final class NetWorthViewModel {
    private let useCase: any NetWorthUseCase
    private var selectedMonth: FinanceMonth?

    public var toastMessage: ToastMessage?
    public var snapshots: [NetWorthSnapshot] = []
    public var planItems: [NetWorthPlanItem] = []
    public var netWorth: NetWorthPresentationModel?

    public init(useCase: any NetWorthUseCase) {
        self.useCase = useCase
        load()
    }

    public func load() {
        do {
            let data = try useCase.load()
            snapshots = data.snapshots
            planItems = data.planItems
            syncNetWorthPresentation()
        } catch {
            showError(error.localizedDescription)
        }
    }

    public func selectMonth(_ month: FinanceMonth) {
        selectedMonth = month
        syncNetWorthPresentation()
    }

    public func createSnapshot(for month: Date) {
        do {
            try useCase.createSnapshot(for: month, calendar: .current)
            load()
        } catch {
            showError(error.localizedDescription)
        }
    }

    public func addSelectedItem(_ input: ValidatedNetWorthItemInput) throws {
        guard let snapshot = selectedSnapshot else { return }
        try addItem(input, to: snapshot, existingItems: planItems)
    }

    public func updateSelectedItem(
        id itemID: UUID,
        input: ValidatedNetWorthItemInput
    ) throws {
        guard let item = planItems.first(where: { $0.id == itemID }),
              let snapshot = selectedSnapshot else {
            return
        }
        try updateItem(item, input: input, snapshot: snapshot, existingItems: planItems)
    }

    public func deleteSelectedItem(id itemID: UUID) throws {
        guard let item = planItems.first(where: { $0.id == itemID }) else { return }
        try deleteItem(item)
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

    public func toggleSelectedSnapshotEditingLock() {
        guard let selectedSnapshot else { return }
        toggleEditingLock(for: selectedSnapshot)
    }

    public func deleteSnapshot(_ snapshot: NetWorthSnapshot) {
        do {
            try useCase.deleteSnapshot(snapshot)
            load()
        } catch {
            showError(error.localizedDescription)
        }
    }

    public func deleteSelectedSnapshot() {
        guard let selectedSnapshot else { return }
        deleteSnapshot(selectedSnapshot)
    }

    private func showError(_ text: String) {
        toastMessage = ToastMessage(text: text, type: .failure)
    }

    private func syncNetWorthPresentation() {
        guard let selectedSnapshot else {
            netWorth = nil
            return
        }
        netWorth = NetWorthPresentationModel(
            snapshot: selectedSnapshot,
            planItems: planItems
        )
    }

    private var selectedSnapshot: NetWorthSnapshot? {
        guard let selectedMonth else { return nil }
        return snapshots.first {
            Calendar.current.isDate($0.asOfDate, equalTo: selectedMonth.startDate, toGranularity: .month)
        }
    }
}
