import Foundation
import Domain
import Utility
import Styleguide

public struct NetWorthItemEditing {
    let id: UUID
    var item: NetWorthItemPresentationModel?
    let category : NetWorthCategoryType
    let categories: [NetWorthCategoryType]
    
    init(
        id: UUID = UUID(),
        item: NetWorthItemPresentationModel? = nil,
        category: NetWorthCategoryType = .cashAndBank,
    ) {
        self.id = id
        self.item = item
        self.category = category
        self.categories = category.groupType.allCategories
    }
}

@Observable
@MainActor
public final class NetWorthViewModel {
    private let useCase: any NetWorthUseCase
    private var selectedMonth: FinanceMonth?
    
    public var toastMessage: ToastMessage?
    public var netWorth: NetWorthPresentationModel?
    public var financeMonths: Set<FinanceMonth> = []
    
    // MARK: Selected Item Support
    public var itemEditing: NetWorthItemEditing?
    public var isEditing: Bool = false
    
    public init(useCase: NetWorthUseCase) {
        self.useCase = useCase
        loadFinanceMonths()
    }

    public func loadFinanceMonths() {
        do {
            financeMonths = try useCase.financeMonths()
        } catch {
            showError(error.localizedDescription)
        }
    }
    
    public func load() {
        do {
            guard let selectedMonth else { return }
            if let networth = try useCase.load(selectedMonth.startDate) {
                self.netWorth = NetWorthPresentationModel(domain: networth)
            } else {
                self.netWorth = nil
            }
            loadFinanceMonths()
        } catch {
            showError(error.localizedDescription)
        }
    }
    
    public func selectMonth(_ month: FinanceMonth) {
        selectedMonth = month
    }
    
    public func createSnapshot(for month: Date) {
        do {
            try useCase.createNetWorth(for: month, calendar: .current)
            load()
        } catch {
            showError(error.localizedDescription)
        }
    }
    
    public func saveItem(_ input: ValidatedNetWorthItemInput) {
        do {
            if let editingItem = itemEditing?.item {
                try updateSelectedItem(id: editingItem.id, input: input)
            } else {
                try addSelectedItem(input)
            }
            Haptic.impact()
        } catch let error as NetWorthItemFormValidationError {
            showError(error.localizationKey.localized)
        } catch {
            showError("networth.item.form.error.save".localized)
        }
    }
    
    public func deleteSelectedItem() {
        guard let itemID = itemEditing?.item?.id, let netWorth = netWorth else { return }
        do {
            try useCase.deleteItem(itemID, in: netWorth.id)
            load()
            Haptic.impact()
        } catch {
            showError("networth.item.form.error.delete".localized)
        }
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
    
    public func showError(_ message: String) {
        toastMessage = ToastMessage(text: message, type: .failure)
    }
}

private extension NetWorthViewModel {
    func addSelectedItem(_ input: ValidatedNetWorthItemInput) throws {
        guard let netWorth = netWorth else { return }
        let networthItem = NetWorthItem(name: input.name, amount: input.amount)
        
        try useCase.addItem(
            networthItem,
            to: input.category,
            in: netWorth.id
        )
        
        load()
    }
    
    func updateSelectedItem(
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
    
}
