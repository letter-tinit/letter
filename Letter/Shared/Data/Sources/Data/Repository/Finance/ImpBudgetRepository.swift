import Domain
import SwiftData
import Foundation

public final class ImpBudgetRepository: BudgetRepository {
    private let modelContext: ModelContext

    public init(modelContext: ModelContext) { self.modelContext = modelContext }

    public func load(_ date: Date) throws -> Budget? {
        let monthStart = Calendar.current.startOfMonth(for: date)
        let descriptor = FetchDescriptor<BudgetRecord>(predicate: #Predicate { $0.month == monthStart })
        return try modelContext.fetch(descriptor).first?.toDomain()
    }

    public func toggleBudgetLock(_ budgetId: UUID) throws {
        guard let budget = try find(budgetId) else { return }
        budget.isLocked.toggle()
        try modelContext.save()
    }

    public func create(_ budget: Budget) throws {
        let record = BudgetRecord(id: budget.id, month: Calendar.current.startOfMonth(for: budget.month),
                                  isLocked: budget.isLocked, incomeAmount: budget.incomeAmount, pyfAmount: budget.pyfAmount)
        modelContext.insert(record)
        try modelContext.save()
    }

    public func delete(_ budgetId: UUID) throws {
        guard let budget = try find(budgetId) else { return }
        modelContext.delete(budget)
        try modelContext.save()
    }

    public func createTransaction(_ transaction: BudgetTransaction, to budgetID: UUID) throws {
        guard let budget = try find(budgetID) else { return }
        let record = makeRecord(transaction)
        record.budget = budget
        budget.transactions.append(record)
        try modelContext.save()
    }

    public func updateTransaction(_ transaction: BudgetTransaction, to budgetID: UUID) throws {
        guard let budget = try find(budgetID), let record = budget.transactions.first(where: { $0.id == transaction.id }) else { return }
        record.amount = transaction.amount
        record.transactionDescription = transaction.description
        record.date = transaction.date
        record.categoryRawValue = transaction.category.rawValue
        try modelContext.save()
    }

    public func deleteTransaction(_ transactionId: UUID, to budgetID: UUID) throws {
        guard let budget = try find(budgetID), let record = budget.transactions.first(where: { $0.id == transactionId }) else { return }
        modelContext.delete(record)
        try modelContext.save()
    }

    private func find(_ id: UUID) throws -> BudgetRecord? {
        try modelContext.fetch(FetchDescriptor<BudgetRecord>(predicate: #Predicate { $0.id == id })).first
    }

    private func makeRecord(_ transaction: BudgetTransaction) -> BudgetTransactionRecord {
        BudgetTransactionRecord(id: transaction.id, amount: transaction.amount, description: transaction.description,
                               date: transaction.date, categoryRawValue: transaction.category.rawValue)
    }
}
