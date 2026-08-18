//
//  SwiftDataBalanceRepository.swift
//  Letter
//
//  Created by TiniT on 20/7/26.
//

import Foundation
import SwiftData

final class SwiftDataBalanceRepository: BalanceRepository {
    private let modelContext: ModelContext
    
    init(modelContext: ModelContext) {
        self.modelContext = modelContext
    }
    
    func firstTransactionMonth() throws -> Date? {
        var descriptor = FetchDescriptor<Transaction>(
            sortBy: [
                SortDescriptor(\.occurredAt, order: .forward)
            ]
        )
        
        descriptor.fetchLimit = 1
        
        return try modelContext.fetch(descriptor)
            .first?
            .occurredAt
            .startOfMonth
    }
    
    func addTransaction(_ transaction: Transaction) throws {
        modelContext.insert(transaction)
        try save()
    }
    
    func updateTransaction(_ transaction: Transaction) throws {
        try save()
    }
    
    func deleteTransaction(_ transaction: Transaction) throws {
        modelContext.delete(transaction)
        try save()
    }
    
    private func save() throws {
        try modelContext.save()
    }
}
