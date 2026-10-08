import Foundation
import Utility

@MainActor
public protocol NetWorthUseCase {
    func load(_ date: Date) throws -> NetWorth?
    func createNetWorth(for month: Date, calendar: Calendar) throws
    func addItem(
        _ item: NetWorthItem,
        to categoryType: NetWorthCategoryType,
        in netWorthID: UUID
    ) throws
    func updateItem(
        _ item: NetWorthItem,
        to categoryType: NetWorthCategoryType,
        in netWorthID: UUID
    ) throws
    func deleteItem(
        _ item: UUID,
        in netWorthID: UUID
    ) throws
    func financeMonths() throws -> Set<FinanceMonth>
    func toggleEditingLock(_ netWorthID: UUID) throws
    func deleteNetWorth(_ netWorthID: UUID) throws
}

@MainActor
public final class ImpNetWorthUseCase: NetWorthUseCase {
    private let repository: any NetWorthRepository
    
    public init(repository: any NetWorthRepository) {
        self.repository = repository
    }
    
    public func load(_ date: Date) throws -> NetWorth? {
        try repository.fetch(date: date)
    }
    
    public func createNetWorth(for month: Date, calendar: Calendar) throws {
        let netWorth = NetWorth(date: month)
        
        try repository.createNetWorth(netWorth)
    }
    
    public func addItem(
        _ item: NetWorthItem,
        to category: NetWorthCategoryType,
        in netWorthID: UUID
    ) throws {
        try repository.addItem(item, to: category, in: netWorthID)
    }
    
    public func updateItem(
        _ item: NetWorthItem,
        to category: NetWorthCategoryType,
        in netWorthID: UUID
    ) throws {
        try repository.updateItem(item, to: category, in: netWorthID)
    }
    
    public func deleteItem(
        _ item: UUID,
        in netWorthID: UUID
    ) throws {
        try repository.deleteItem(item, in: netWorthID)
    }
    
    public func financeMonths() throws -> Set<FinanceMonth> {
        let dates = try repository.fetchDates()

        return Set(dates.map { FinanceMonth($0) })
    }
    
    public func toggleEditingLock(_ netWorthID: UUID) throws {
        try repository.toggleEditingLock(netWorthID)
    }
    
    public func deleteNetWorth(_ netWorthID: UUID) throws {
        try repository.deleteNetWorth(netWorthID)
    }
}
