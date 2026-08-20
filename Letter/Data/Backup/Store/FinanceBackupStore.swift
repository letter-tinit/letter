//
//  FinanceBackupStore.swift
//  Letter
//
//  Created by Codex on 22/7/26.
//

import Foundation
import SwiftData

enum FinanceBackupStoreError: LocalizedError {
    case unsupportedSchemaVersion(Int)
    case invalidFile
    case saveFailed

    var errorDescription: String? {
        switch self {
        case .unsupportedSchemaVersion:
            return "profile.backup.error.unsupportedSchema".localized
        case .invalidFile:
            return "profile.backup.error.invalidFile".localized
        case .saveFailed:
            return "profile.backup.error.save".localized
        }
    }
}

final class FinanceBackupStore {
    private let modelContext: ModelContext

    init(modelContext: ModelContext) {
        self.modelContext = modelContext
    }

    func exportBackup() throws -> FinanceBackup {
        let transactions = try modelContext.fetch(FetchDescriptor<Transaction>(
            sortBy: [SortDescriptor(\.occurredAt, order: .reverse)]
        )).map {
            TransactionBackup(
                id: $0.id,
                note: $0.note,
                type: $0.type,
                category: $0.category,
                method: $0.method,
                amount: $0.amount,
                occurredAt: $0.occurredAt,
                createAt: $0.createAt
            )
        }

        let budgets = try modelContext.fetch(FetchDescriptor<Budget>(
            sortBy: [SortDescriptor(\.periodStart, order: .reverse)]
        )).map { budget in
            BudgetBackup(
                id: budget.id,
                periodStart: budget.periodStart,
                income: budget.income,
                method: budget.method,
                createdAt: budget.createdAt,
                isLocked: budget.isLocked,
                allocations: budget.allocations.map { allocation in
                    BudgetAllocationBackup(
                        id: allocation.id,
                        kind: allocation.kind,
                        ratio: allocation.ratio,
                        targetAmount: allocation.targetAmount,
                        transactions: allocation.transactions.map(\.id),
                        fixedExpensePlans: allocation.fixedExpensePlans.map(\.id)
                    )
                },
                fixedExpensePlans: budget.fixedExpensePlans.map { plan in
                    FixedExpensePlanBackup(
                        id: plan.id,
                        allocationID: plan.allocation?.id,
                        name: plan.name,
                        amount: plan.amount,
                        amountType: plan.amountType,
                        transactionID: plan.transaction?.id
                    )
                },
                transactions: budget.transactions.map { transaction in
                    BudgetTransactionBackup(
                        id: transaction.id,
                        allocationID: transaction.allocation?.id,
                        type: transaction.type,
                        title: transaction.title,
                        note: transaction.note,
                        occurredAt: transaction.occurredAt,
                        amount: transaction.amount,
                        paymentMethod: transaction.paymentMethod,
                        fixedExpensePlanID: transaction.fixedExpensePlan?.id
                    )
                }
            )
        }

        let netWorthPlanItems = try modelContext.fetch(FetchDescriptor<NetWorthPlanItem>(
            sortBy: [SortDescriptor(\.displayOrder)]
        )).map { item in
            NetWorthPlanItemBackup(
                id: item.id,
                category: item.category,
                name: item.name,
                displayOrder: item.displayOrder
            )
        }
        let netWorthSnapshots = try modelContext.fetch(FetchDescriptor<NetWorthSnapshot>(
            sortBy: [SortDescriptor(\.asOfDate, order: .reverse)]
        )).map { snapshot in
            NetWorthSnapshotBackup(
                id: snapshot.id,
                asOfDate: snapshot.asOfDate,
                values: snapshot.values.map { value in
                    NetWorthValueBackup(
                        id: value.id,
                        amount: value.amount,
                        planItemID: value.planItem?.id
                    )
                },
                isLocked: snapshot.isLocked
            )
        }

        let balanceMonths = try modelContext.fetch(FetchDescriptor<BalanceMonth>(
            sortBy: [SortDescriptor(\.monthStart, order: .reverse)]
        )).map {
            BalanceMonthBackup(monthStart: $0.monthStart, isLocked: $0.isLocked)
        }

        return FinanceBackup(
            schemaVersion: FinanceBackup.schemaVersion,
            backupDate: .now,
            transactions: transactions,
            budgets: budgets,
            netWorthPlanItems: netWorthPlanItems,
            netWorthSnapshots: netWorthSnapshots,
            balanceMonths: balanceMonths
        )
    }

    func importBackup(_ backup: FinanceBackup) throws {
        guard backup.schemaVersion == FinanceBackup.schemaVersion else {
            throw FinanceBackupStoreError.unsupportedSchemaVersion(backup.schemaVersion)
        }

        do {
            try clearExistingData()
            try insert(backup)
            try save()
        } catch {
            modelContext.rollback()
            throw error
        }
    }

    func clearAllData() throws {
        try clearExistingData()
        try save()
    }

    private func clearExistingData() throws {
        deleteAll(try modelContext.fetch(FetchDescriptor<BudgetTransaction>()))
        deleteAll(try modelContext.fetch(FetchDescriptor<FixedExpensePlan>()))
        deleteAll(try modelContext.fetch(FetchDescriptor<BudgetAllocation>()))
        deleteAll(try modelContext.fetch(FetchDescriptor<Budget>()))
        deleteAll(try modelContext.fetch(FetchDescriptor<Transaction>()))

        // SwiftData can leave relationship-backed properties as faults after a
        // model is deleted. NetWorthView keeps the @Query results alive while
        // this operation runs, so resolving these values first prevents a
        // subsequent SwiftUI render from reading `category` from detached
        // NetWorthPlanItem backing data.
        let netWorthValues = try modelContext.fetch(FetchDescriptor<NetWorthValue>())
        let netWorthSnapshots = try modelContext.fetch(FetchDescriptor<NetWorthSnapshot>())
        let netWorthPlanItems = try modelContext.fetch(FetchDescriptor<NetWorthPlanItem>())
        materializeNetWorthData(
            values: netWorthValues,
            snapshots: netWorthSnapshots,
            planItems: netWorthPlanItems
        )

        deleteAll(netWorthValues)
        deleteAll(netWorthSnapshots)
        deleteAll(netWorthPlanItems)
        deleteAll(try modelContext.fetch(FetchDescriptor<BalanceMonth>()))
    }

    private func materializeNetWorthData(
        values: [NetWorthValue],
        snapshots: [NetWorthSnapshot],
        planItems: [NetWorthPlanItem]
    ) {
        values.forEach { value in
            _ = value.id
            _ = value.amount
            _ = value.planItem?.id
            _ = value.snapshot?.id
        }
        snapshots.forEach { snapshot in
            _ = snapshot.id
            _ = snapshot.asOfDate
            _ = snapshot.isLocked
            _ = snapshot.values.map { $0.id }
        }
        planItems.forEach { item in
            _ = item.id
            _ = item.category
            _ = item.name
            _ = item.displayOrder
            _ = item.values.map { $0.id }
        }
    }

    private func deleteAll<T: PersistentModel>(_ models: [T]) {
        models.forEach { modelContext.delete($0) }
    }

    private func insert(_ backup: FinanceBackup) throws {
        let allocationSource = Dictionary(uniqueKeysWithValues: backup.budgets.flatMap { $0.allocations }.map { ($0.id, $0) })

        for transaction in backup.transactions {
            modelContext.insert(Transaction(
                id: transaction.id,
                note: transaction.note,
                type: transaction.type,
                category: transaction.category,
                method: transaction.method,
                amount: transaction.amount,
                occurredAt: transaction.occurredAt,
                createAt: transaction.createAt
            ))
        }

        var allocationModels: [UUID: BudgetAllocation] = [:]
        var transactionModels: [UUID: BudgetTransaction] = [:]
        var planModels: [UUID: FixedExpensePlan] = [:]

        for budgetBackup in backup.budgets {
            let budget = Budget(
                id: budgetBackup.id,
                periodStart: budgetBackup.periodStart,
                income: budgetBackup.income,
                method: budgetBackup.method,
                createdAt: budgetBackup.createdAt
            )
            budget.isLocked = budgetBackup.isLocked ?? true
            modelContext.insert(budget)

            for allocationBackup in budgetBackup.allocations {
                let allocation = BudgetAllocation(
                    id: allocationBackup.id,
                    budget: budget,
                    kind: allocationBackup.kind,
                    ratio: allocationBackup.ratio,
                    targetAmount: allocationBackup.targetAmount
                )
                allocationModels[allocation.id] = allocation
                budget.allocations.append(allocation)
                modelContext.insert(allocation)
            }

            for transactionBackup in budgetBackup.transactions {
                let transaction = BudgetTransaction(
                    id: transactionBackup.id,
                    budget: budget,
                    allocation: transactionBackup.allocationID.flatMap { allocationSource[$0] }.flatMap { allocationModels[$0.id] },
                    type: transactionBackup.type,
                    title: transactionBackup.title,
                    note: transactionBackup.note,
                    occurredAt: transactionBackup.occurredAt,
                    amount: transactionBackup.amount,
                    paymentMethod: transactionBackup.paymentMethod
                )
                transactionModels[transaction.id] = transaction
                budget.transactions.append(transaction)
                modelContext.insert(transaction)
            }

            for planBackup in budgetBackup.fixedExpensePlans {
                let plan = FixedExpensePlan(
                    id: planBackup.id,
                    budget: budget,
                    allocation: planBackup.allocationID.flatMap { allocationSource[$0] }.flatMap { allocationModels[$0.id] },
                    name: planBackup.name,
                    amount: planBackup.amount,
                    amountType: planBackup.amountType
                )
                planModels[plan.id] = plan
                budget.fixedExpensePlans.append(plan)
                modelContext.insert(plan)
            }
        }

        for budgetBackup in backup.budgets {
            for allocationBackup in budgetBackup.allocations {
                guard let allocation = allocationModels[allocationBackup.id] else { continue }
                allocation.transactions = allocationBackup.transactions.compactMap { transactionModels[$0] }
                allocation.fixedExpensePlans = allocationBackup.fixedExpensePlans.compactMap { planModels[$0] }
            }
        }

        for budgetBackup in backup.budgets {
            for planBackup in budgetBackup.fixedExpensePlans {
                if let transactionID = planBackup.transactionID,
                   let transaction = transactionModels[transactionID],
                   let plan = planModels[planBackup.id] {
                    plan.transaction = transaction
                    transaction.fixedExpensePlan = plan
                }
            }
        }

        var itemModels: [UUID: NetWorthPlanItem] = [:]
        for itemBackup in backup.netWorthPlanItems {
            let item = NetWorthPlanItem(
                id: itemBackup.id,
                category: itemBackup.category,
                name: itemBackup.name,
                displayOrder: itemBackup.displayOrder
            )
            itemModels[item.id] = item
            modelContext.insert(item)
        }

        for snapshotBackup in backup.netWorthSnapshots {
            let snapshot = NetWorthSnapshot(id: snapshotBackup.id, asOfDate: snapshotBackup.asOfDate)
            snapshot.isLocked = snapshotBackup.isLocked ?? true
            modelContext.insert(snapshot)

            for valueBackup in snapshotBackup.values {
                let value = NetWorthValue(id: valueBackup.id, amount: valueBackup.amount)
                value.planItem = valueBackup.planItemID.flatMap { itemModels[$0] }
                value.snapshot = snapshot
                snapshot.values.append(value)
                modelContext.insert(value)
            }
        }

        for monthBackup in backup.balanceMonths ?? [] {
            modelContext.insert(
                BalanceMonth(monthStart: monthBackup.monthStart, isLocked: monthBackup.isLocked)
            )
        }
    }

    private func save() throws {
        guard modelContext.hasChanges else { return }
        try modelContext.save()
    }
}
