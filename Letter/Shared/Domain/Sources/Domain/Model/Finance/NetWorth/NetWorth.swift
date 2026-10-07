//
//  NetWorth.swift
//  Letter
//
//  Created by TiniT on 15/7/26.
//
//

import Foundation

// MARK: - Net Worth
public struct NetWorth: Identifiable {
    public let id: UUID
    public let date: Date
    public var isLocked: Bool
    public var categories: [NetWorthCategoryType: NetWorthCategory]
    
    public init(
        id: UUID = UUID(),
        date: Date,
        isLocked: Bool = false,
        categories: [NetWorthCategoryType: NetWorthCategory] = [:],
    ) {
        self.id = id
        self.date = date
        self.isLocked = isLocked
        self.categories = categories
    }
}

// MARK: - Net Worth Category
public struct NetWorthCategory: Identifiable {
    public let id: UUID
    public let type: NetWorthCategoryType
    public var items: [NetWorthItem]
    
    public init(
        id: UUID = UUID(),
        type: NetWorthCategoryType,
        items: [NetWorthItem]
    ) {
        self.id = id
        self.type = type
        self.items = items
    }
}

// MARK: - Net Worth Item
public struct NetWorthItem: Identifiable {
    public let id: UUID
    public var name: String
    public var amount: Decimal
    
    public init(
        id: UUID = UUID(),
        name: String,
        amount: Decimal
    ) {
        self.id = id
        self.name = name
        self.amount = amount
    }
}

// MARK: - Group Type
public enum NetWorthGroupType: String, CaseIterable, Codable, Hashable {
    case assets
    case liabilities
}

// MARK: - Category Type
public enum NetWorthCategoryType: String, CaseIterable, Codable, Hashable {
    // Assets
    case cashAndBank
    case receivables
    case personalProperty
    case investment
    
    // Liabilities
    case credit
    case shortTermDebt
    case longTermDebt
    
    public var group: NetWorthGroupType {
        switch self {
        case .cashAndBank,
                .receivables,
                .personalProperty,
                .investment:
            return .assets
            
        case .credit,
                .shortTermDebt,
                .longTermDebt:
            return .liabilities
        }
    }
}

public extension NetWorth {
    // MARK: - Add
    mutating func addItem(
        _ item: NetWorthItem,
        to category: NetWorthCategoryType
    ) {
        var netWorthCategory = categories[category]
            ?? NetWorthCategory(
                type: category,
                items: []
            )

        netWorthCategory.items.append(item)
        categories[category] = netWorthCategory
    }

    // MARK: - Update
    mutating func updateItem(
        _ item: NetWorthItem,
        category newCategory: NetWorthCategoryType
    ) {
        guard let oldCategory = categories.first(where: {
            $0.value.items.contains { $0.id == item.id }
        })?.key else {
            return
        }

        // Same category → replace item
        if oldCategory == newCategory {
            guard var category = categories[oldCategory],
                  let index = category.items.firstIndex(
                    where: { $0.id == item.id }
                  )
            else {
                return
            }

            category.items[index] = item
            categories[oldCategory] = category
            return
        }

        // Remove from old category
        if var oldCategoryValue = categories[oldCategory] {
            oldCategoryValue.items.removeAll {
                $0.id == item.id
            }

            if oldCategoryValue.items.isEmpty {
                // No item left → remove category
                categories.removeValue(forKey: oldCategory)
            } else {
                categories[oldCategory] = oldCategoryValue
            }
        }

        // Add to new category
        var newCategoryValue = categories[newCategory]
            ?? NetWorthCategory(
                type: newCategory,
                items: []
            )

        newCategoryValue.items.append(item)
        categories[newCategory] = newCategoryValue
    }

    // MARK: - Remove
    mutating func removeItem(
        id: UUID
    ) {
        for categoryType in categories.keys {
            guard var category = categories[categoryType] else {
                continue
            }

            category.items.removeAll {
                $0.id == id
            }

            guard category.items.isEmpty else {
                categories[categoryType] = category
                return
            }

            // No item left → remove category
            categories.removeValue(forKey: categoryType)
            return
        }
    }
}
