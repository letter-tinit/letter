import Foundation
import Observation
import Domain

// MARK: - Net Worth
public struct NetWorthPresentationModel: Identifiable {
    // MARK: Properties
    public let id: UUID
    public let date: Date
    public let isLocked: Bool
    public var assets: [NetWorthCategoryPresentationModel]
    public var liabilities: [NetWorthCategoryPresentationModel]
    
    // MARK: Initialization
    public init(domain: NetWorth) {
        self.id = domain.id
        self.date = domain.date
        self.isLocked = domain.isLocked
        self.assets = domain.categories.values
            .filter { $0.type.group == .assets }
            .map(NetWorthCategoryPresentationModel.init)

        self.liabilities = domain.categories.values
            .filter { $0.type.group == .liabilities }
            .map(NetWorthCategoryPresentationModel.init)
    }
}

extension NetWorthPresentationModel {
    public var missingItemCount: Int {
        (assets + liabilities).reduce(0) { count, category in
            count + category.items.count(where: {
                $0.amount == .zero
            })
        }
    }
}

// MARK: - Net Worth Category
public struct NetWorthCategoryPresentationModel: Identifiable, Equatable, Hashable {
    // MARK: Properties
    public let id: UUID
    public let type: NetWorthCategoryType
    public var items: [NetWorthItemPresentationModel]
    
    // MARK: Computed Properties
    public var totalAmount: Decimal {
        items
            .map({ $0.amount })
            .compactMap({ $0 })
            .reduce(0) {
                $0 + $1
            }
    }
    
    // MARK: Initialization
    public init(domain: NetWorthCategory) {
        self.id = domain.id
        self.type = domain.type
        self.items = domain.items.map {
            NetWorthItemPresentationModel(domain: $0)
        }
    }
}

public extension Collection
where Element == NetWorthCategoryPresentationModel {
    var totalAmount: Decimal {
        reduce(Decimal.zero) { total, category in
            total + category.totalAmount
        }
    }
}

// MARK: - Net Worth Item
public struct NetWorthItemPresentationModel: Identifiable, Equatable, Hashable {
    // MARK: Properties
    public let id: UUID
    public let name: String
    public var amount: Decimal?
    
    // MARK: Initialization
    public init(domain: NetWorthItem) {
        self.id = domain.id
        self.name = domain.name
        self.amount = domain.amount
    }
}

// MARK: - Net Worth Presentation Helpers
public extension NetWorthPresentationModel {
    var totalAssets: Decimal {
        assets.reduce(0) {
            $0 + $1.totalAmount
        }
    }
    
    var totalLiabilities: Decimal {
        liabilities.reduce(0) {
            $0 + $1.totalAmount
        }
    }
    
    var netWorth: Decimal {
        totalAssets - totalLiabilities
    }
}
