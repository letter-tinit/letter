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

    public func fetchDates() throws -> [Date] {
        try modelContext.fetch(FetchDescriptor<BudgetRecord>(sortBy: [SortDescriptor(\.month, order: .reverse)])).map(\.month)
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
        record.fixedPlanID = transaction.fixedPlanID
        try modelContext.save()
    }

    public func deleteTransaction(_ transactionId: UUID, to budgetID: UUID) throws {
        guard let budget = try find(budgetID), let record = budget.transactions.first(where: { $0.id == transactionId }) else { return }
        modelContext.delete(record)
        try modelContext.save()
    }

    public func fixedPlans() throws -> [BudgetFixedPlan] {
        try modelContext.fetch(FetchDescriptor<BudgetFixedPlanRecord>(sortBy: [SortDescriptor(\.planDescription)]))
            .map { $0.toDomain() }
    }

    public func saveFixedPlan(_ plan: BudgetFixedPlan, for budgetID: UUID?) throws {
        let record: BudgetFixedPlanRecord
        let planID = plan.id
        if let existing = try modelContext.fetch(FetchDescriptor<BudgetFixedPlanRecord>(predicate: #Predicate { $0.id == planID })).first {
            record = existing
            record.planDescription = plan.description
            record.amount = plan.amount
            record.categoryRawValue = plan.category.rawValue
        } else {
            record = BudgetFixedPlanRecord(id: plan.id, description: plan.description, amount: plan.amount,
                                           categoryRawValue: plan.category.rawValue)
            modelContext.insert(record)
        }

        if let budgetID,
           let budget = try find(budgetID),
           !budget.isLocked,
           let transaction = budget.transactions.first(where: { $0.fixedPlanID == plan.id }) {
            transaction.transactionDescription = plan.description
            transaction.amount = plan.amount
            transaction.categoryRawValue = plan.category.rawValue
        }
        try modelContext.save()
    }

    public func deleteFixedPlan(_ planID: UUID) throws {
        if let plan = try modelContext.fetch(FetchDescriptor<BudgetFixedPlanRecord>(predicate: #Predicate { $0.id == planID })).first {
            modelContext.delete(plan)
        }
        try modelContext.save()
    }

    public func applyFixedPlan(_ planID: UUID, to budgetID: UUID, on date: Date) throws {
        guard let budget = try find(budgetID),
              !budget.isLocked,
              let plan = try modelContext.fetch(FetchDescriptor<BudgetFixedPlanRecord>(predicate: #Predicate { $0.id == planID })).first,
              !budget.transactions.contains(where: { $0.fixedPlanID == planID }) else { return }

        let transaction = BudgetTransactionRecord(id: UUID(), amount: plan.amount, description: plan.planDescription,
                                                  date: date, categoryRawValue: plan.categoryRawValue, fixedPlanID: planID)
        transaction.budget = budget
        budget.transactions.append(transaction)
        modelContext.insert(transaction)
        try modelContext.save()
    }

    private func find(_ id: UUID) throws -> BudgetRecord? {
        try modelContext.fetch(FetchDescriptor<BudgetRecord>(predicate: #Predicate { $0.id == id })).first
    }

    private func makeRecord(_ transaction: BudgetTransaction) -> BudgetTransactionRecord {
        BudgetTransactionRecord(id: transaction.id, amount: transaction.amount, description: transaction.description,
                               date: transaction.date, categoryRawValue: transaction.category.rawValue,
                               fixedPlanID: transaction.fixedPlanID)
    }
}
