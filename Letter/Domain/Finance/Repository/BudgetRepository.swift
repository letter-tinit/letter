//
//  BudgetRepository.swift
//  Personal Finance
//
//  Created by TiniT on 22/7/26.
//

protocol BudgetRepository {
    func fetchBudgets() throws -> [Budget]
    func addBudget(_ budget: Budget) throws
    func removeBudget(_ budget: Budget) throws
    func lockBudget(_ budget: Budget) throws
    func deleteTransaction(_ transaction: BudgetTransaction) throws
    func deleteFixedExpensePlan(_ plan: FixedExpensePlan) throws
    func save() throws
}
