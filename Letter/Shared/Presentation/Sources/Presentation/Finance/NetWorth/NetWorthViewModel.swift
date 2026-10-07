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
    public var netWorth: NetWorthPresentationModel?
    public var financeMonths: Set<FinanceMonth> = []
    
    // MARK: Selected Item Support
    public var editingItem: NetWorthItemPresentationModel?
    public var editingItemCategory: NetWorthCategoryType = .cashAndBank
    public var itemFormEditing: Bool = false
    
    public init(useCase: NetWorthUseCase) {
        self.useCase = useCase
        getFinanceMonths()
    }
    
    private func getFinanceMonths() {
        financeMonths = useCase.financeMonths()
    }
    
    public func load() {
        do {
            guard let selectedMonth else { return }
            if let networth = try useCase.load(selectedMonth.startDate) {
                self.netWorth = NetWorthPresentationModel(domain: networth)
            } else {
                self.netWorth = nil
            }
            getFinanceMonths()
        } catch {
            showError(error.localizedDescription)
        }
    }
    
    public func selectMonth(_ month: FinanceMonth) {
        selectedMonth = month
    }
    
    public func createSnapshot(for month: Date) {
        do {
            try useCase.createSnapshot(for: month, calendar: .current)
            load()
        } catch {
            showError(error.localizedDescription)
        }
    }
    
    public func saveItem(_ input: ValidatedNetWorthItemInput) throws {
        if let editingItem {
            try updateSelectedItem(id: editingItem.id, input: input)
        } else {
            try addSelectedItem(input)
        }
    }
    
    private func addSelectedItem(_ input: ValidatedNetWorthItemInput) throws {
        guard let netWorth = netWorth else { return }
        let networthItem = NetWorthItem(name: input.name, amount: input.amount)
        
        try useCase.addItem(
            networthItem,
            to: input.category,
            in: netWorth.id
        )
        
        load()
    }
    
    private func updateSelectedItem(
        id itemID: UUID,
        input: ValidatedNetWorthItemInput
    ) throws {
        guard let netWorth = netWorth else { return }
        let networthItem = NetWorthItem(id: itemID, name: input.name, amount: input.amount)
        try useCase.updateItem(
            networthItem,
            to: input.category,
            in: netWorth.id
        )
        
        load()
    }
    
    public func deleteSelectedItem() throws {
        guard let itemID = editingItem?.id, let netWorth = netWorth else { return }
        try useCase.deleteItem(itemID, in: netWorth.id)
        load()
    }
    
    public func presentEditForm(_ item: NetWorthItemPresentationModel? = nil, category: NetWorthCategoryType = .cashAndBank) {
        editingItem = item
        editingItemCategory = category
        itemFormEditing = true
    }
    
    public func toggleEditingLock() {
        guard let netWorth = netWorth else { return }
        do {
            try useCase.toggleEditingLock(netWorth.id)
            load()
        } catch {
            showError(error.localizedDescription)
        }
    }
    
    public func isNetWorthLocked() -> Bool {
        guard let netWorth = netWorth else {
            return false
        }
        
        return netWorth.isLocked
    }
    
    public func removeCurrentNetWorth() {
        guard let netWorth = netWorth else { return }
        do {
            try useCase.deleteNetWorth(netWorth.id)
            load()
        } catch {
            showError(error.localizedDescription)
        }
    }
    
    private func showError(_ text: String) {
        toastMessage = ToastMessage(text: text, type: .failure)
    }
}
