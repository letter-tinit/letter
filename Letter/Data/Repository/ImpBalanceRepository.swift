import Foundation
import SwiftData

@MainActor
final class ImpBalanceRepository: BalanceRepository {
    private let modelContext: ModelContext

    init(modelContext: ModelContext) {
        self.modelContext = modelContext
    }

    func fetchTransactions() throws -> [Transaction] {
        try modelContext.fetch(FetchDescriptor<TransactionRecord>(
            sortBy: [SortDescriptor(\.occurredAt, order: .reverse)]
        )).map(makeTransaction)
    }

    func fetchBalanceMonths() throws -> [BalanceMonth] {
        try modelContext.fetch(FetchDescriptor<BalanceMonthRecord>()).map {
            BalanceMonth(monthStart: $0.monthStart, isLocked: $0.isLocked)
        }
    }

    func saveTransaction(_ transaction: Transaction) throws {
        let record = try transactionRecord(id: transaction.id) ?? TransactionRecord(
            id: transaction.id,
            note: transaction.note,
            type: transaction.type,
            category: transaction.category,
            method: transaction.method,
            amount: transaction.amount,
            occurredAt: transaction.occurredAt,
            createAt: transaction.createAt
        )
        record.note = transaction.note
        record.type = transaction.type
        record.category = transaction.category
        record.method = transaction.method
        record.amount = transaction.amount
        record.occurredAt = transaction.occurredAt
        record.createAt = transaction.createAt
        if record.modelContext == nil { modelContext.insert(record) }
        try modelContext.save()
    }

    func deleteTransaction(id: UUID) throws {
        if let record = try transactionRecord(id: id) { modelContext.delete(record) }
        try modelContext.save()
    }

    func deleteTransactions(ids: Set<UUID>) throws {
        try modelContext.fetch(FetchDescriptor<TransactionRecord>())
            .filter { ids.contains($0.id) }
            .forEach(modelContext.delete)
        try modelContext.save()
    }

    func saveBalanceMonth(_ month: BalanceMonth) throws {
        let record = try balanceMonthRecord(id: month.id)
            ?? BalanceMonthRecord(monthStart: month.monthStart, isLocked: month.isLocked)
        record.monthStart = month.monthStart
        record.isLocked = month.isLocked
        if record.modelContext == nil { modelContext.insert(record) }
        try modelContext.save()
    }

    private func transactionRecord(id: UUID) throws -> TransactionRecord? {
        try modelContext.fetch(FetchDescriptor<TransactionRecord>()).first { $0.id == id }
    }

    private func balanceMonthRecord(id: Date) throws -> BalanceMonthRecord? {
        try modelContext.fetch(FetchDescriptor<BalanceMonthRecord>()).first { $0.id == id }
    }

    private func makeTransaction(_ record: TransactionRecord) -> Transaction {
        Transaction(
            id: record.id,
            note: record.note,
            type: record.type,
            category: record.category,
            method: record.method,
            amount: record.amount,
            occurredAt: record.occurredAt,
            createAt: record.createAt
        )
    }
}
