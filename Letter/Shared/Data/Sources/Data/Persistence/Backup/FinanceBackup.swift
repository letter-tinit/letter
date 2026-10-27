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
    public let netWorths: [NetWorthBackup]
    public let balanceMonths: [BalanceMonthBackup]?
    public let budgets: [BudgetBackup]

    private enum CodingKeys: String, CodingKey {
        case schemaVersion, backupDate, transactions, netWorths, balanceMonths, budgets
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        schemaVersion = try container.decode(Int.self, forKey: .schemaVersion)
        backupDate = try container.decode(Date.self, forKey: .backupDate)
        transactions = try container.decode([TransactionBackup].self, forKey: .transactions)
        netWorths = try container.decode([NetWorthBackup].self, forKey: .netWorths)
        balanceMonths = try container.decodeIfPresent([BalanceMonthBackup].self, forKey: .balanceMonths)
        budgets = try container.decodeIfPresent([BudgetBackup].self, forKey: .budgets) ?? []
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(schemaVersion, forKey: .schemaVersion)
        try container.encode(backupDate, forKey: .backupDate)
        try container.encode(transactions, forKey: .transactions)
        try container.encode(netWorths, forKey: .netWorths)
        try container.encodeIfPresent(balanceMonths, forKey: .balanceMonths)
        try container.encode(budgets, forKey: .budgets)
    }

    public init(schemaVersion: Int, backupDate: Date, transactions: [TransactionBackup], netWorths: [NetWorthBackup], balanceMonths: [BalanceMonthBackup]?, budgets: [BudgetBackup]) {
        self.schemaVersion = schemaVersion
        self.backupDate = backupDate
        self.transactions = transactions
        self.netWorths = netWorths
        self.balanceMonths = balanceMonths
        self.budgets = budgets
    }
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

public struct BalanceMonthBackup: Codable {
    public let monthStart: Date
    public let isLocked: Bool
}

public struct BudgetBackup: Codable {
    public let id: UUID
    public let month: Date
    public let isLocked: Bool
    public let incomeAmount: Decimal
    public let pyfAmount: Decimal
    public let transactions: [BudgetTransactionBackup]

    init(_ record: BudgetRecord) {
        id = record.id
        month = record.month
        isLocked = record.isLocked
        incomeAmount = record.incomeAmount
        pyfAmount = record.pyfAmount
        transactions = record.transactions.map(BudgetTransactionBackup.init)
    }
}

public struct BudgetTransactionBackup: Codable {
    public let id: UUID
    public let amount: Decimal
    public let description: String
    public let date: Date
    public let categoryRawValue: String

    init(_ record: BudgetTransactionRecord) {
        id = record.id
        amount = record.amount
        description = record.transactionDescription
        date = record.date
        categoryRawValue = record.categoryRawValue
    }
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
