//
//  FinanceBackup.swift
//  Letter
//
//  Created by Codex on 22/7/26.
//

import Foundation
import Domain
import Utility

nonisolated
public struct FinanceBackup: Codable {
    public static let schemaVersion = 1

    public let schemaVersion: Int
    public let backupDate: Date
    public let transactions: [TransactionBackup]
    public let budgets: [BudgetBackup]
    public let netWorths: [NetWorthBackup]
    public let balanceMonths: [BalanceMonthBackup]?
}

public struct TransactionBackup: Codable {
    public let id: UUID
    public let note: String?
    public let type: TransactionType
    public let category: TransactionCategory
    public let method: PaymentMethod
    public let amount: Decimal
    public let occurredAt: Date
    public let createAt: Date
}

public struct BudgetBackup: Codable {
    public let id: UUID
    public let periodStart: Date
    public let income: Decimal
    public let method: BudgetMethod
    public let createdAt: Date
    public let isLocked: Bool?
    public let allocations: [BudgetAllocationBackup]
    public let fixedExpensePlans: [FixedExpensePlanBackup]
    public let transactions: [BudgetTransactionBackup]
}

public struct BudgetAllocationBackup: Codable {
    public let id: UUID
    public let kind: BudgetBucketKind
    public let ratio: Decimal
    public let targetAmount: Decimal
    public let transactions: [UUID]
    public let fixedExpensePlans: [UUID]
}

public struct FixedExpensePlanBackup: Codable {
    public let id: UUID
    public let allocationID: UUID?
    public let name: String
    public let amount: Decimal
    public let amountType: FixedExpensePlanAmountType
    public let transactionID: UUID?
}

public struct BudgetTransactionBackup: Codable {
    public let id: UUID
    public let allocationID: UUID?
    public let type: TransactionType
    public let title: String
    public let note: String
    public let occurredAt: Date
    public let amount: Decimal
    public let paymentMethod: PaymentMethod
    public let fixedExpensePlanID: UUID?
}

public struct BalanceMonthBackup: Codable {
    public let monthStart: Date
    public let isLocked: Bool
}

// MARK: - NetWorth
public struct NetWorthBackup: Codable {
    public let id: UUID
    public let date: Date
    public let isLocked: Bool
    public let categories: [NetWorthCategoryBackup]
    
    init(_ persistence: NetWorthModel) {
        self.id = persistence.id
        self.date = persistence.date
        self.isLocked = persistence.isLocked
        self.categories = persistence.categories.map({ NetWorthCategoryBackup($0) })
    }
}

public struct NetWorthCategoryBackup: Codable {
    public let id: UUID
    public let typeRawValue: String
    public let items: [NetWorthItemBackup]
    public let netWorthID: UUID?
    
    init(_ persistence: NetWorthCategoryModel) {
        self.id = persistence.id
        self.typeRawValue = persistence.typeRawValue
        self.items = persistence.items.map({ NetWorthItemBackup($0) })
        self.netWorthID = persistence.netWorth?.id
    }
}

public struct NetWorthItemBackup: Codable {
    public let id: UUID
    public let name: String
    public let amount: Decimal?
    public let categoryID: UUID?
    
    init(_ persistence: NetWorthItemModel) {
        self.id = persistence.id
        self.name = persistence.name
        self.amount = persistence.amount
        self.categoryID = persistence.category?.id
    }
}
