//
//  SwiftDataBudgetRepository.swift
//  Letter
//
//  Created by TiniT on 22/7/26.
//

import Foundation
import SwiftData

final class ImpBudgetRepository: BudgetRepository {
    private let modelContext: ModelContext
    init(modelContext: ModelContext) { self.modelContext = modelContext }

    func fetchBudgets() throws -> [Budget] {
        let descriptor = FetchDescriptor<Budget>(sortBy: [SortDescriptor(\.periodStart, order: .reverse)])
        return try modelContext.fetch(descriptor)
    }

    func addBudget(_ budget: Budget) throws {
        modelContext.insert(budget)   // cascade insert allocations tự động
        try save()
    }

    func removeBudget(_ budget: Budget) throws {
        modelContext.delete(budget)
        try save()
    }
    
    func deleteTransaction(_ transaction: BudgetTransaction) throws {
        modelContext.delete(transaction)
        try save()
    }

    func deleteFixedExpensePlan(_ plan: FixedExpensePlan) throws {
        modelContext.delete(plan)
        try save()
    }

    func save() throws {
        try modelContext.save()
    }
}
