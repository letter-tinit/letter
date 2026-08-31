//
//  BalanceRepository.swift
//  Letter
//
//  Created by TiniT on 20/7/26.
//

import Foundation

public protocol BalanceRepository {
    func fetchTransactions() throws -> [Transaction]
    func fetchBalanceMonths() throws -> [BalanceMonth]
    func fetchBalanceMonth(monthStart: Date) throws -> BalanceMonth?
    func saveTransaction(_ transaction: Transaction) throws
    func deleteTransaction(id: UUID) throws
    func deleteTransactions(ids: Set<UUID>) throws
    func saveBalanceMonth(_ month: BalanceMonth) throws
}
