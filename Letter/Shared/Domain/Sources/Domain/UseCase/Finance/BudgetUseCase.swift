//
//  BudgetUseCase.swift
//  Domain
//
//  Created by Tín Nguyễn on 15/10/26.
//

import Foundation

public protocol BudgetUseCase {
    func load(_ date: Date) throws -> Budget?
    func createTransaction(_ transaction: BudgetTransaction, to budgetID: UUID) throws
    func deleteTransaction(_ transactionId: UUID, to budgetID: UUID) throws
}

public final class ImpBudgetUseCase: BudgetUseCase {
    private let repository: any BudgetRepository
    
    public init(repository: any BudgetRepository) {
        self.repository = repository
    }
    
    public func load(_ date: Date) throws -> Budget? {
        try repository.load(date)
    }
    
    public func createTransaction(_ transaction: BudgetTransaction, to budgetID: UUID) throws {
        try repository.createTransaction(transaction, to: budgetID)
    }
    
    public func deleteTransaction(_ transactionId: UUID, to budgetID: UUID) throws {
        try repository.deleteTransaction(transactionId, to: budgetID)
    }
}
