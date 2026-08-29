//
//  SwiftDataBalanceRepository.swift
//  Letter
//
//  Created by TiniT on 20/7/26.
//

import Foundation
import SwiftData

final class ImpBalanceRepository: BalanceRepository {
    private let modelContext: ModelContext
    
    init(modelContext: ModelContext) {
        self.modelContext = modelContext
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

    func deleteTransactions(_ transactions: [Transaction]) throws {
        transactions.forEach(modelContext.delete)
        try save()
    }

    func addBalanceMonth(_ month: BalanceMonth) throws {
        modelContext.insert(month)
        try save()
    }

    func save() throws {
        try modelContext.save()
    }
}
