//
//  BudgetUseCase.swift
//  Domain
//
//  Created by Tín Nguyễn on 15/10/26.
//

import Foundation

public protocol BudgetUseCase {
    func load(_ date: Date) throws -> Budget?
    func budgetMonths() throws -> Set<FinanceMonth>
    func toggleBudgetLock(_ budgetId: UUID) throws
    func create(_ budget: Budget) throws
    func delete(_ budgetId: UUID) throws
    func createTransaction(_ transaction: BudgetTransaction, to budgetID: UUID) throws
    func updateTransaction(_ transaction: BudgetTransaction, to budgetID: UUID) throws
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

    public func budgetMonths() throws -> Set<FinanceMonth> {
        Set(try repository.fetchDates().map { FinanceMonth($0) })
    }
    
    public func toggleBudgetLock(_ budgetId: UUID) throws {
        try repository.toggleBudgetLock(budgetId)
    }
    
    public func create(_ budget: Budget) throws {
        try repository.create(budget)
    }
    
    public func delete(_ budgetId: UUID) throws {
        try repository.delete(budgetId)
    }
    
    public func createTransaction(_ transaction: BudgetTransaction, to budgetID: UUID) throws {
        try repository.createTransaction(transaction, to: budgetID)
    }
    
    public func updateTransaction(_ transaction: BudgetTransaction, to budgetID: UUID) throws {
        try repository.updateTransaction(transaction, to: budgetID)
    }
    
    public func deleteTransaction(_ transactionId: UUID, to budgetID: UUID) throws {
        try repository.deleteTransaction(transactionId, to: budgetID)
    }
}
