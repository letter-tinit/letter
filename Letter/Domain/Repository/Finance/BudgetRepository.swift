import Foundation

//
//  BudgetRepository.swift
//  Letter
//
//  Created by TiniT on 22/7/26.
//

protocol BudgetRepository {
    func fetchBudgets() throws -> [Budget]
    func saveBudget(_ budget: Budget) throws
    func deleteBudget(id: UUID) throws
}
