//
//  ImpBudgetRepository.swift
//  Data
//
//  Created by Tín Nguyễn on 15/10/26.
//

import Domain
import SwiftData
import Foundation

public final class ImpBudgetRepository: BudgetRepository {
    private let modelContext: ModelContext
    
    public init(modelContext: ModelContext) {
        self.modelContext = modelContext
    }
    
    public func load(_ date: Date) throws -> Budget? {
        return Budget(
            id: UUID(),
            month: Calendar.current.date(
                from: DateComponents(year: 2026, month: 10, day: 1)
            )!,
            isLocked: false,
            incomeAmount: 20_000_000,
            pyfAmount: 4_000_000,
            transactions: [
                BudgetTransaction(
                    id: UUID(),
                    amount: 150_000,
                    description: "Groceries",
                    date: Calendar.current.date(
                        from: DateComponents(year: 2026, month: 10, day: 5)
                    )!,
                    category: .eWallet
                ),
                BudgetTransaction(
                    id: UUID(),
                    amount: 50_000,
                    description: "Coffee",
                    date: Calendar.current.date(
                        from: DateComponents(year: 2026, month: 10, day: 8)
                    )!,
                    category: .food
                ),
                BudgetTransaction(
                    id: UUID(),
                    amount: 50_000,
                    description: "Coffee",
                    date: Calendar.current.date(
                        from: DateComponents(year: 2026, month: 10, day: 8)
                    )!,
                    category: .transport
                ),
                BudgetTransaction(
                    id: UUID(),
                    amount: 50_000,
                    description: "Coffee",
                    date: Calendar.current.date(
                        from: DateComponents(year: 2026, month: 10, day: 8)
                    )!,
                    category: .shopping
                ),
                BudgetTransaction(
                    id: UUID(),
                    amount: 200_000,
                    description: "Dinner",
                    date: Calendar.current.date(
                        from: DateComponents(year: 2026, month: 10, day: 12)
                    )!,
                    category: .bills
                ),
                BudgetTransaction(
                    id: UUID(),
                    amount: 200_000,
                    description: "Dinner",
                    date: Calendar.current.date(
                        from: DateComponents(year: 2026, month: 10, day: 12)
                    )!,
                    category: .other
                ),
                BudgetTransaction(
                    id: UUID(),
                    amount: 200_000,
                    description: "Dinner",
                    date: Calendar.current.date(
                        from: DateComponents(year: 2026, month: 10, day: 12)
                    )!,
                    category: .shopping
                )
            ]
        )
    }
}
