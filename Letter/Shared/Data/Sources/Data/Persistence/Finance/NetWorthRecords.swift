
import Foundation
import SwiftData
import Domain

// MARK: - Net Worth
@Model
public final class NetWorthModel {
    @Attribute(.unique)
    public var id: UUID
    
    public var date: Date
    public var isLocked: Bool
    
    @Relationship(deleteRule: .cascade, inverse: \NetWorthCategoryModel.netWorth)
    public var categories: [NetWorthCategoryModel]
    
    public init(
        id: UUID = UUID(),
        date: Date,
        isLocked: Bool = false,
        categories: [NetWorthCategoryModel] = []
    ) {
        self.id = id
        self.date = date
        self.isLocked = isLocked
        self.categories = categories
    }
}

// MARK: - Net Worth Category
@Model
public final class NetWorthCategoryModel {
    @Attribute(.unique)
    public var id: UUID
    
    public var typeRawValue: String
    
    @Relationship(deleteRule: .cascade, inverse: \NetWorthItemModel.category)
    public var items: [NetWorthItemModel]
    
    public var netWorth: NetWorthModel?
    
    public init(
        id: UUID = UUID(),
        type: NetWorthCategoryType,
        items: [NetWorthItemModel] = []
    ) {
        self.id = id
        self.typeRawValue = type.rawValue
        self.items = items
    }
    
    public var type: NetWorthCategoryType {
        get {
            NetWorthCategoryType(rawValue: typeRawValue)!
        }
        set {
            typeRawValue = newValue.rawValue
        }
    }
}

// MARK: - Net Worth Item
@Model
public final class NetWorthItemModel {
    @Attribute(.unique)
    public var id: UUID
    
    public var name: String
    public var amount: Decimal
    
    public var category: NetWorthCategoryModel?
    
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

extension NetWorthModel {
    func toDomain() -> NetWorth {
        let categories = Dictionary(
            uniqueKeysWithValues: categories.map { categoryModel in
                (
                    categoryModel.type,
                    categoryModel.toDomain()
                )
            }
        )
        
        return NetWorth(
            id: id,
            date: date,
            isLocked: isLocked,
            categories: categories
        )
    }
}

extension NetWorthCategoryModel {
    func toDomain() -> NetWorthCategory {
        NetWorthCategory(
            id: id,
            type: type,
            items: items.map { $0.toDomain() }
        )
    }
}

extension NetWorthItemModel {
    func toDomain() -> NetWorthItem {
        NetWorthItem(
            id: id,
            name: name,
            amount: amount
        )
    }
}
