import Foundation
import Utility

@MainActor
public protocol NetWorthUseCase {
    func load(_ date: Date) throws -> NetWorth?
    func createSnapshot(for month: Date, calendar: Calendar) throws
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
    func financeMonths() -> Set<FinanceMonth>
    func toggleEditingLock(_ netWorthID: UUID) throws
    func deleteNetWorth(_ netWorthID: UUID) throws
}

@MainActor
public final class ImpNetWorthUseCase: NetWorthUseCase {
    private let repository: any NetWorthRepository
    private var netWorths: [NetWorth] = []
    
    public init(repository: any NetWorthRepository) {
        self.repository = repository
    }
    
    public func load(_ date: Date) throws -> NetWorth? {
        netWorths.first { netWorth in
            netWorth.date.isInSameMonth(as: date)
        }
    }
    
    public func createSnapshot(for month: Date, calendar: Calendar) throws {
        let netWorth = NetWorth(date: month)
        
        netWorths.append(netWorth)
    }
    
    public func addItem(
        _ item: NetWorthItem,
        to category: NetWorthCategoryType,
        in netWorthID: UUID
    ) throws {
        guard let index = getNetworthIndexByID(netWorthID) else {
            return
        }
        
        netWorths[index].addItem(item, to: category)
    }
    
    public func updateItem(
        _ item: NetWorthItem,
        to category: NetWorthCategoryType,
        in netWorthID: UUID
    ) throws {
        guard let index = getNetworthIndexByID(netWorthID) else {
            return
        }
        
        netWorths[index].updateItem(item, category: category)
    }
    
    public func deleteItem(
        _ item: UUID,
        in netWorthID: UUID
    )
    throws {
        guard let index = getNetworthIndexByID(netWorthID) else {
            return
        }
        
        netWorths[index].removeItem(id: item)
    }
    
    private func getNetworthIndexByID(_ netWorthID: UUID) -> Int? {
        guard let index = netWorths.firstIndex(where: {
            $0.id == netWorthID
        }) else {
            return nil
        }
        
        return index
    }
    
    public func financeMonths() -> Set<FinanceMonth> {
        Set(netWorths.map { FinanceMonth($0.date) })
    }
    
    public func toggleEditingLock(_ netWorthID: UUID) throws {
        guard let index = getNetworthIndexByID(netWorthID) else {
            return
        }
        
        netWorths[index].isLocked.toggle()
    }
    
    public func deleteNetWorth(_ netWorthID: UUID) throws {
        guard let index = getNetworthIndexByID(netWorthID) else {
            return
        }
        
        netWorths.remove(at: index)
    }
}
