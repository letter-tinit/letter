import Foundation
import SwiftData
import Domain

@MainActor
public final class ImpNetWorthRepository: NetWorthRepository {
    private let modelContext: ModelContext
    
    public init(modelContext: ModelContext) {
        self.modelContext = modelContext
    }
    
    public func fetch(date: Date) throws -> NetWorth? {
        let descriptor = FetchDescriptor<NetWorthModel>(
            predicate: #Predicate { $0.date == date }
        )
        
        guard let model = try modelContext.fetch(descriptor).first else {
            return nil
        }
        
        return model.toDomain()
    }
    
    public func createNetWorth(
        _ netWorth: NetWorth
    ) throws {
        let recentNetWorth = try getRecentlyNetWorth(
            before: netWorth.date
        )

        let categories: [NetWorthCategoryModel] = recentNetWorth?.categories.map { category in
            let categoryModel = NetWorthCategoryModel(
                id: UUID(),
                typeRawValue: category.typeRawValue
            )

            categoryModel.items = category.items.map { item in
                let itemModel = NetWorthItemModel(
                    id: UUID(),
                    name: item.name,
                    amount: nil
                )

                itemModel.category = categoryModel

                return itemModel
            }

            return categoryModel
        } ?? []

        let model = NetWorthModel(
            id: netWorth.id,
            date: netWorth.date,
            isLocked: netWorth.isLocked,
            categories: categories
        )

        try create(model)
    }
    
    public func addItem(
        _ item: NetWorthItem,
        to category: NetWorthCategoryType,
        in netWorthID: UUID
    ) throws {
        let descriptor = FetchDescriptor<NetWorthModel>(
            predicate: #Predicate {
                $0.id == netWorthID
            }
        )

        guard let netWorth = try modelContext.fetch(descriptor).first else {
            return
        }

        let categoryModel: NetWorthCategoryModel

        if let existingCategory = netWorth.categories.first(where: {
            $0.type == category
        }) {
            categoryModel = existingCategory
        } else {
            categoryModel = NetWorthCategoryModel(
                typeRawValue: category.rawValue
            )

            categoryModel.netWorth = netWorth
            netWorth.categories.append(categoryModel)
        }

        let itemModel = NetWorthItemModel(
            id: item.id,
            name: item.name,
            amount: item.amount
        )

        itemModel.category = categoryModel
        categoryModel.items.append(itemModel)

        try modelContext.save()
    }
    
    public func updateItem(
        _ item: NetWorthItem,
        to category: NetWorthCategoryType,
        in netWorthID: UUID
    ) throws {
        let descriptor = FetchDescriptor<NetWorthModel>(
            predicate: #Predicate {
                $0.id == netWorthID
            }
        )

        guard let netWorth = try modelContext.fetch(descriptor).first else {
            return
        }

        // Find the current category and item
        guard let oldCategory = netWorth.categories.first(where: {
            $0.items.contains { $0.id == item.id }
        }),
        let itemIndex = oldCategory.items.firstIndex(where: {
            $0.id == item.id
        }) else {
            return
        }

        // Same category → update existing item
        if oldCategory.type == category {
            let existingItem = oldCategory.items[itemIndex]

            existingItem.name = item.name
            existingItem.amount = item.amount

            try modelContext.save()
            return
        }

        // Remove item from old category
        let existingItem = oldCategory.items.remove(at: itemIndex)

        // Remove old category if empty
        if oldCategory.items.isEmpty {
            netWorth.categories.removeAll {
                $0.id == oldCategory.id
            }
        }

        // Find or create new category
        let newCategory: NetWorthCategoryModel

        if let existingCategory = netWorth.categories.first(where: {
            $0.type == category
        }) {
            newCategory = existingCategory
        } else {
            newCategory = NetWorthCategoryModel(
                typeRawValue: category.rawValue
            )

            newCategory.netWorth = netWorth
            netWorth.categories.append(newCategory)
        }

        // Update and move the existing item
        existingItem.name = item.name
        existingItem.amount = item.amount
        existingItem.category = newCategory

        newCategory.items.append(existingItem)

        try modelContext.save()
    }
    
    public func deleteItem(
        _ item: UUID,
        in netWorthID: UUID
    ) throws {
        let descriptor = FetchDescriptor<NetWorthModel>(
            predicate: #Predicate {
                $0.id == netWorthID
            }
        )
        
        guard let netWorth = try modelContext.fetch(descriptor).first else {
            return
        }
        
        // Find the category containing the item
        guard let category = netWorth.categories.first(where: {
            $0.items.contains { $0.id == item }
        }) else {
            return
        }
        
        // Remove item
        category.items.removeAll {
            $0.id == item
        }
        
        // Remove category if it has no items
        if category.items.isEmpty {
            netWorth.categories.removeAll {
                $0.id == category.id
            }
        }
        
        try modelContext.save()
    }
    
    public func fetchDates() throws -> [Date] {
        let descriptor = FetchDescriptor<NetWorthModel>(
            sortBy: [
                SortDescriptor(\.date, order: .reverse)
            ]
        )
        
        return try modelContext.fetch(descriptor).map(\.date)
    }
    
    public func toggleEditingLock(
        _ netWorthID: UUID
    ) throws {
        let descriptor = FetchDescriptor<NetWorthModel>(
            predicate: #Predicate {
                $0.id == netWorthID
            }
        )
        
        guard let netWorth = try modelContext.fetch(descriptor).first else {
            return
        }
        
        netWorth.isLocked.toggle()
        
        try modelContext.save()
    }
    
    public func deleteNetWorth(
        _ netWorthID: UUID
    ) throws {
        let descriptor = FetchDescriptor<NetWorthModel>(
            predicate: #Predicate {
                $0.id == netWorthID
            }
        )
        
        guard let netWorth = try modelContext.fetch(descriptor).first else {
            return
        }
        
        modelContext.delete(netWorth)
        
        try modelContext.save()
    }
}

private extension ImpNetWorthRepository {
    func create(
        _ model: NetWorthModel
    ) throws {
        modelContext.insert(model)
        try modelContext.save()
    }
    
    func getRecentlyNetWorth(
        before date: Date
    ) throws -> NetWorthModel? {
        let targetDate = date

        let descriptor = FetchDescriptor<NetWorthModel>(
            predicate: #Predicate {
                $0.date < targetDate
            },
            sortBy: [
                SortDescriptor(\.date, order: .reverse)
            ]
        )

        return try modelContext.fetch(descriptor).first
    }
}
