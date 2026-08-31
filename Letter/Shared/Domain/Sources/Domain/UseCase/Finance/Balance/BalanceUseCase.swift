import Foundation

public protocol BalanceUseCase {
    func load() throws -> BalanceData
    func saveTransaction(_ transaction: Transaction) throws -> BalanceData
    func deleteTransaction(id: UUID) throws -> BalanceData
    func toggleEditingLock(for month: BalanceMonth) throws -> BalanceData
    func deleteTransactions(ids: Set<UUID>) throws -> BalanceData
}

public final class ImpBalanceUseCase: BalanceUseCase {
    private let repository: any BalanceRepository

    public init(repository: any BalanceRepository) {
        self.repository = repository
    }

    public func load() throws -> BalanceData {
        BalanceData(
            transactions: try repository.fetchTransactions(),
            months: try repository.fetchBalanceMonths()
        )
    }

    public func saveTransaction(_ transaction: Transaction) throws -> BalanceData {
        try repository.saveTransaction(transaction)
        return try load()
    }

    public func deleteTransaction(id: UUID) throws -> BalanceData {
        try repository.deleteTransaction(id: id)
        return try load()
    }

    public func toggleEditingLock(for month: BalanceMonth) throws -> BalanceData {
        var updated = try repository.fetchBalanceMonth(monthStart: month.monthStart) ?? month
        updated.isLocked.toggle()
        try repository.saveBalanceMonth(updated)
        return try load()
    }

    public func deleteTransactions(ids: Set<UUID>) throws -> BalanceData {
        try repository.deleteTransactions(ids: ids)
        return try load()
    }
}
