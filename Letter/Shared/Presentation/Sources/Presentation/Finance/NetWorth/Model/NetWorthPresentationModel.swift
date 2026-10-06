import Foundation
import Observation
import Domain

// MARK: - Net Worth
public struct NetWorthPresentationModel: Identifiable {
    // MARK: Properties
    public let id: UUID
    public var date: Date
    public var isLocked: Bool
    public var groups: [NetWorthGroupPresentationModel]
    
    // MARK: Initialization
    public init(domain: NetWorth) {
        self.id = domain.id
        self.date = domain.date
        self.isLocked = domain.isLocked
        self.groups = domain.groups.map {
            NetWorthGroupPresentationModel(domain: $0)
        }
    }
}

// MARK: - Net Worth Group
public struct NetWorthGroupPresentationModel: Identifiable {
    // MARK: Properties
    public let id: UUID
    public let type: NetWorthGroupType
    public var categories: [NetWorthCategoryPresentationModel]
    
    // MARK: Computed Properties
    public var totalAmount: Decimal {
        categories
            .reduce(0) {
                $0 + $1.totalAmount
            }
    }
    
    // MARK: Initialization
    public init(domain: NetWorthGroup) {
        self.id = domain.id
        self.type = domain.type
        self.categories = domain.categories.map {
            NetWorthCategoryPresentationModel(domain: $0)
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
            .reduce(0) {
                $0 + $1.amount
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

// MARK: - Net Worth Item
public struct NetWorthItemPresentationModel: Identifiable, Equatable, Hashable {
    // MARK: Properties
    public let id: UUID
    public let name: String
    public var amount: Decimal
    
    // MARK: Initialization
    public init(domain: NetWorthItem) {
        self.id = domain.id
        self.name = domain.name
        self.amount = domain.amount ?? .zero
    }
}

// MARK: - Net Worth Presentation Helpers
public extension NetWorthPresentationModel {
    var assetGroups: [NetWorthGroupPresentationModel] {
        groups.filter {
            $0.type == .assets
        }
    }
    
    var liabilityGroups: [NetWorthGroupPresentationModel] {
        groups.filter {
            $0.type == .liabilities
        }
    }
    
    var totalAssets: Decimal {
        assetGroups.reduce(0) {
            $0 + $1.totalAmount
        }
    }
    
    var totalLiabilities: Decimal {
        liabilityGroups.reduce(0) {
            $0 + $1.totalAmount
        }
    }
    
    var netWorth: Decimal {
        totalAssets - totalLiabilities
    }
}
