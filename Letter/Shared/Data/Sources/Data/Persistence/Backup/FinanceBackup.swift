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
    public static let schemaVersion = 2

    public let schemaVersion: Int
    public let backupDate: Date
    public let transactions: [TransactionBackup]
    public let budgets: [BudgetBackup]
    public let netWorthPlanItems: [NetWorthPlanItemBackup]
    public let netWorthSnapshots: [NetWorthSnapshotBackup]
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

public struct NetWorthPlanItemBackup: Codable {
    public let id: UUID
    public let category: NetWorthCategory
    public let name: String
    public let displayOrder: Int
}

public struct NetWorthSnapshotBackup: Codable {
    public let id: UUID
    public let asOfDate: Date
    public let values: [NetWorthValueBackup]
    public let isLocked: Bool?
}

public struct BalanceMonthBackup: Codable {
    public let monthStart: Date
    public let isLocked: Bool
}

public struct NetWorthValueBackup: Codable {
    public let id: UUID
    public let amount: Decimal?
    public let planItemID: UUID?
}
