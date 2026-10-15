//
//  ImpBudgetRepository.swift
//  Data
//
//  Created by Tín Nguyễn on 15/10/26.
//

import Domain
import SwiftData

public final class ImpBudgetRepository: BudgetRepository {
    private let modelContext: ModelContext
    
    public init(modelContext: ModelContext) {
        self.modelContext = modelContext
    }
}
