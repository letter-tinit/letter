//
//  PersonalFinanceBackup.swift
//  Personal Finance
//
//  Created by Codex on 22/7/26.
//

import Foundation

nonisolated
struct PersonalFinanceBackup: Codable {
    static let schemaVersion = 1

    let schemaVersion: Int
    let backupDate: Date
    let transactions: [TransactionBackup]
    let budgets: [BudgetBackup]
    let netWorthYears: [NetWorthYearBackup]
}

struct TransactionBackup: Codable {
    let id: UUID
    let note: String?
    let type: TransactionType
    let category: TransactionCategory
    let method: PaymentMethod
    let amount: Decimal
    let occurredAt: Date
    let createAt: Date
}

struct BudgetBackup: Codable {
    let id: UUID
    let periodStart: Date
    let income: Decimal
    let method: BudgetMethod
    let createdAt: Date
    let allocations: [BudgetAllocationBackup]
    let fixedExpensePlans: [FixedExpensePlanBackup]
    let transactions: [BudgetTransactionBackup]
}

struct BudgetAllocationBackup: Codable {
    let id: UUID
    let kind: BudgetBucketKind
    let ratio: Decimal
    let targetAmount: Decimal
    let transactions: [UUID]
    let fixedExpensePlans: [UUID]
}

struct FixedExpensePlanBackup: Codable {
    let id: UUID
    let allocationID: UUID?
    let name: String
    let amount: Decimal
    let amountType: FixedExpensePlanAmountType
    let transactionID: UUID?
}

struct BudgetTransactionBackup: Codable {
    let id: UUID
    let allocationID: UUID?
    let type: TransactionType
    let title: String
    let note: String
    let occurredAt: Date
    let amount: Decimal
    let paymentMethod: PaymentMethod
    let fixedExpensePlanID: UUID?
}

struct NetWorthYearBackup: Codable {
    let id: UUID
    let year: Int
    let planItems: [NetWorthPlanItemBackup]
    let snapshots: [NetWorthSnapshotBackup]
}

struct NetWorthPlanItemBackup: Codable {
    let id: UUID
    let category: NetWorthCategory
    let name: String
    let displayOrder: Int
}

struct NetWorthSnapshotBackup: Codable {
    let id: UUID
    let asOfDate: Date
    let values: [NetWorthValueBackup]
}

struct NetWorthValueBackup: Codable {
    let id: UUID
    let amount: Decimal?
    let planItemID: UUID?
}
