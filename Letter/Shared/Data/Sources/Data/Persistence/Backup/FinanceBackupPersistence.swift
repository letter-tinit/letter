//
//  FinanceBackupPersistence.swift
//  Letter
//
//  Created by Codex on 22/7/26.
//

import Foundation
import SwiftData
import Domain
import Utility

public enum FinanceBackupPersistenceError: LocalizedError {
    case unsupportedSchemaVersion(Int)
    case invalidFile
    case saveFailed

    public var errorDescription: String? {
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

public final class FinanceBackupPersistence {
    private let modelContext: ModelContext

    public init(modelContext: ModelContext) {
        self.modelContext = modelContext
    }

    public func exportBackup() throws -> FinanceBackup {
        let transactions = try modelContext.fetch(FetchDescriptor<TransactionRecord>(
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

        let netWorths = try modelContext.fetch(
            FetchDescriptor<NetWorthModel>(
                sortBy: [
                    SortDescriptor(\.date, order: .reverse)
                ]
            )
        ).map(NetWorthBackup.init)

        let balanceMonths = try modelContext.fetch(FetchDescriptor<BalanceMonthRecord>(
            sortBy: [SortDescriptor(\.monthStart, order: .reverse)]
        )).map {
            BalanceMonthBackup(monthStart: $0.monthStart, isLocked: $0.isLocked)
        }

        let budgets = try modelContext.fetch(FetchDescriptor<BudgetRecord>(
            sortBy: [SortDescriptor(\.month, order: .reverse)]
        )).map(BudgetBackup.init)

        let budgetFixedPlans = try modelContext.fetch(FetchDescriptor<BudgetFixedPlanRecord>(
            sortBy: [SortDescriptor(\.planDescription)]
        )).map(BudgetFixedPlanBackup.init)

        return FinanceBackup(
            schemaVersion: FinanceBackup.schemaVersion,
            backupDate: .now,
            transactions: transactions,
            netWorths: netWorths,
            balanceMonths: balanceMonths,
            budgets: budgets,
            budgetFixedPlans: budgetFixedPlans
        )
    }

    public func importBackup(_ backup: FinanceBackup) throws {
        guard backup.schemaVersion == FinanceBackup.schemaVersion else {
            throw FinanceBackupPersistenceError.unsupportedSchemaVersion(backup.schemaVersion)
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

    public func clearAllData() throws {
        try clearExistingData()
        try save()
    }

    private func clearExistingData() throws {
        deleteAll(try modelContext.fetch(FetchDescriptor<TransactionRecord>()))
        deleteAll(try modelContext.fetch(FetchDescriptor<NetWorthModel>()))
        deleteAll(try modelContext.fetch(FetchDescriptor<BalanceMonthRecord>()))
        deleteAll(try modelContext.fetch(FetchDescriptor<BudgetRecord>()))
        deleteAll(try modelContext.fetch(FetchDescriptor<BudgetFixedPlanRecord>()))
    }

    private func deleteAll<T: PersistentModel>(_ models: [T]) {
        models.forEach { modelContext.delete($0) }
    }

    private func insert(_ backup: FinanceBackup) throws {
        for transaction in backup.transactions {
            modelContext.insert(TransactionRecord(
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

        for monthBackup in backup.balanceMonths ?? [] {
            modelContext.insert(
                BalanceMonthRecord(monthStart: monthBackup.monthStart, isLocked: monthBackup.isLocked)
            )
        }

        for budgetBackup in backup.budgets {
            let budget = BudgetRecord(id: budgetBackup.id, month: budgetBackup.month, isLocked: budgetBackup.isLocked,
                                      incomeAmount: budgetBackup.incomeAmount, pyfAmount: budgetBackup.pyfAmount)
            modelContext.insert(budget)
            for transactionBackup in budgetBackup.transactions {
                let transaction = BudgetTransactionRecord(id: transactionBackup.id, amount: transactionBackup.amount,
                                                          description: transactionBackup.description, date: transactionBackup.date,
                                                          categoryRawValue: transactionBackup.categoryRawValue,
                                                          fixedPlanID: transactionBackup.fixedPlanID)
                transaction.budget = budget
                budget.transactions.append(transaction)
                modelContext.insert(transaction)
            }
        }

        for planBackup in backup.budgetFixedPlans {
            modelContext.insert(BudgetFixedPlanRecord(id: planBackup.id, description: planBackup.description,
                                                      amount: planBackup.amount, categoryRawValue: planBackup.categoryRawValue))
        }
        
        // NETWORTH
        for netWorthBackup in backup.netWorths {
            let netWorth = NetWorthModel(
                id: netWorthBackup.id,
                date: netWorthBackup.date,
                isLocked: netWorthBackup.isLocked
            )
            modelContext.insert(netWorth)

            for categoryBackup in netWorthBackup.categories {
                let category = NetWorthCategoryModel(
                    id: categoryBackup.id,
                    typeRawValue: categoryBackup.typeRawValue
                )

                category.netWorth = netWorth
                netWorth.categories.append(category)
                modelContext.insert(category)

                for itemBackup in categoryBackup.items {
                    let item = NetWorthItemModel(
                        id: itemBackup.id,
                        name: itemBackup.name,
                        amount: itemBackup.amount
                    )

                    item.category = category
                    category.items.append(item)
                    modelContext.insert(item)
                }
            }
        }
    }

    private func save() throws {
        guard modelContext.hasChanges else { return }
        try modelContext.save()
    }
}
