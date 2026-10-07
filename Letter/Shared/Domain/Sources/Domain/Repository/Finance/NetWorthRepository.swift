import Foundation
import Utility

@MainActor
public protocol NetWorthRepository {
    func fetchAll() throws -> [NetWorth]
    func fetch(date: Date) throws -> NetWorth?
    func create(_ netWorth: NetWorth) throws
    func addItem(
        _ item: NetWorthItem,
        to category: NetWorthCategoryType,
        in netWorthID: UUID
    ) throws
    func updateItem(
        _ item: NetWorthItem,
        to category: NetWorthCategoryType,
        in netWorthID: UUID
    ) throws
    func deleteItem(
        _ item: UUID,
        in netWorthID: UUID
    )
    throws
    func fetchDates() throws -> [Date]
    func toggleEditingLock(
        _ netWorthID: UUID
    ) throws
    func deleteNetWorth(
        _ netWorthID: UUID
    ) throws
}
