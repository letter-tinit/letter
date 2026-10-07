import Foundation
import SwiftData
import Domain

@MainActor
public final class ImpNetWorthRepository: NetWorthRepository {
    private let modelContext: ModelContext
    
    public init(modelContext: ModelContext) {
        self.modelContext = modelContext
    }
    
    public func fetchAll() throws -> [NetWorth] {
        let descriptor = FetchDescriptor<NetWorthModel>(
            sortBy: [
                SortDescriptor(\.date, order: .reverse)
            ]
        )
        
        let models = try modelContext.fetch(descriptor)
        
        return models.map { $0.toDomain() }
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
    
    public func create(_ netWorth: NetWorth) throws {
        let model = NetWorthModel(
            id: netWorth.id,
            date: netWorth.date,
            isLocked: netWorth.isLocked,
            categories: netWorth.categories.values.map { category in
                NetWorthCategoryModel(
                    id: category.id,
                    type: category.type,
                    items: category.items.map { item in
                        NetWorthItemModel(
                            id: item.id,
                            name: item.name,
                            amount: item.amount
                        )
                    }
                )
            }
        )
        
        modelContext.insert(model)
        try modelContext.save()
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
            categoryModel = NetWorthCategoryModel(type: category)
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
        
        // Find the item's current category
        guard let oldCategory = netWorth.categories.first(where: {
            $0.items.contains { $0.id == item.id }
        }) else {
            return
        }
        
        // Same category → update item
        if oldCategory.type == category {
            guard let existingItem = oldCategory.items.first(where: {
                $0.id == item.id
            }) else {
                return
            }
            
            existingItem.name = item.name
            existingItem.amount = item.amount
            
            try modelContext.save()
            return
        }
        
        // Different category → remove from old category
        oldCategory.items.removeAll {
            $0.id == item.id
        }
        
        // Remove empty category
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
            newCategory = NetWorthCategoryModel(type: category)
            newCategory.netWorth = netWorth
            netWorth.categories.append(newCategory)
        }
        
        // Add updated item to new category
        let itemModel = NetWorthItemModel(
            id: item.id,
            name: item.name,
            amount: item.amount
        )
        
        itemModel.category = newCategory
        newCategory.items.append(itemModel)
        
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
