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
