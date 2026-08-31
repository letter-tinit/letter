import Foundation
import SwiftData
import Domain
import Core
import Utility

@MainActor
public final class ImpBudgetRepository: BudgetRepository {
    private let modelContext: ModelContext

    public init(modelContext: ModelContext) {
        self.modelContext = modelContext
    }

    public func fetchBudgets() throws -> [Budget] {
        try modelContext.fetch(FetchDescriptor<BudgetRecord>(
            sortBy: [SortDescriptor(\.periodStart, order: .reverse)]
        )).map(makeBudget)
    }

    public func saveBudget(_ budget: Budget) throws {
        if let existing = try record(id: budget.id) {
            modelContext.delete(existing)
            try modelContext.save()
        }
        modelContext.insert(makeRecord(from: budget))
        try modelContext.save()
    }

    public func deleteBudget(id: UUID) throws {
        if let record = try record(id: id) { modelContext.delete(record) }
        try modelContext.save()
    }

    private func record(id: UUID) throws -> BudgetRecord? {
        try modelContext.fetch(FetchDescriptor<BudgetRecord>()).first { $0.id == id }
    }

    private func makeRecord(from budget: Budget) -> BudgetRecord {
        let record = BudgetRecord(
            id: budget.id,
            periodStart: budget.periodStart,
            income: budget.income,
            isLocked: budget.isLocked,
            method: budget.method,
            createdAt: budget.createdAt
        )
        let allocations = Dictionary(uniqueKeysWithValues: budget.allocations.map { allocation in
            let child = BudgetAllocationRecord(
                id: allocation.id,
                kind: allocation.kind,
                ratio: allocation.ratio,
                targetAmount: allocation.targetAmount
            )
            child.budget = record
            return (allocation.id, child)
        })
        let transactions = Dictionary(uniqueKeysWithValues: budget.transactions.map { transaction in
            let child = BudgetTransactionRecord(
                id: transaction.id,
                type: transaction.type,
                title: transaction.title,
                note: transaction.note,
                occurredAt: transaction.occurredAt,
                amount: transaction.amount,
                paymentMethod: transaction.paymentMethod
            )
            child.budget = record
            child.allocation = transaction.allocation.flatMap { allocations[$0.id] }
            return (transaction.id, child)
        })
        let plans = Dictionary(uniqueKeysWithValues: budget.fixedExpensePlans.map { plan in
            let child = FixedExpensePlanRecord(
                id: plan.id,
                name: plan.name,
                amount: plan.amount,
                amountType: plan.amountType
            )
            child.budget = record
            child.allocation = plan.allocation.flatMap { allocations[$0.id] }
            return (plan.id, child)
        })
        for transaction in budget.transactions {
            guard let recordTransaction = transactions[transaction.id] else { continue }
            recordTransaction.fixedExpensePlan = transaction.fixedExpensePlan.flatMap { plans[$0.id] }
        }
        record.allocations = Array(allocations.values)
        record.transactions = Array(transactions.values)
        record.fixedExpensePlans = Array(plans.values)
        return record
    }

    private func makeBudget(_ record: BudgetRecord) -> Budget {
        let budget = Budget(
            id: record.id,
            periodStart: record.periodStart,
            income: record.income,
            method: record.method,
            createdAt: record.createdAt
        )
        budget.isLocked = record.isLocked
        let allocations = Dictionary(uniqueKeysWithValues: record.allocations.map { allocation in
            let child = BudgetAllocation(
                id: allocation.id,
                budget: budget,
                kind: allocation.kind,
                ratio: allocation.ratio,
                targetAmount: allocation.targetAmount
            )
            return (child.id, child)
        })
        let transactions = Dictionary(uniqueKeysWithValues: record.transactions.map { transaction in
            let allocation = transaction.allocation.flatMap { allocations[$0.id] }
            let child = BudgetTransaction(
                id: transaction.id,
                budget: budget,
                allocation: allocation,
                type: transaction.type,
                title: transaction.title,
                note: transaction.note,
                occurredAt: transaction.occurredAt,
                amount: transaction.amount,
                paymentMethod: transaction.paymentMethod
            )
            allocation?.transactions.append(child)
            return (child.id, child)
        })
        let plans = Dictionary(uniqueKeysWithValues: record.fixedExpensePlans.map { plan in
            let allocation = plan.allocation.flatMap { allocations[$0.id] }
            let child = FixedExpensePlan(
                id: plan.id,
                budget: budget,
                allocation: allocation,
                name: plan.name,
                amount: plan.amount,
                amountType: plan.amountType
            )
            allocation?.fixedExpensePlans.append(child)
            return (child.id, child)
        })
        for transactionRecord in record.transactions {
            guard let transaction = transactions[transactionRecord.id],
                  let planRecord = transactionRecord.fixedExpensePlan,
                  let plan = plans[planRecord.id] else { continue }
            transaction.fixedExpensePlan = plan
            plan.transaction = transaction
        }
        budget.allocations = Array(allocations.values)
        budget.transactions = Array(transactions.values)
        budget.fixedExpensePlans = Array(plans.values)
        return budget
    }
}
