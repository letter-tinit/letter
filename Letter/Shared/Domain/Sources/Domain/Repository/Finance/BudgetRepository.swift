//
//  BudgetRepository.swift
//  Domain
//
//  Created by Tín Nguyễn on 15/10/26.
//

import Foundation

public protocol BudgetRepository {
    func load(_ date: Date) throws -> Budget?
    func createTransaction(_ transaction: BudgetTransaction, to budgetID: UUID) throws
    func deleteTransaction(_ transactionId: UUID, to budgetID: UUID) throws
}
