//
//  PreviewHelper.swift
//  Letter
//
//  Created by TiniT on 20/7/26.
//

import SwiftData

struct PreviewHelper {
    @MainActor
    static func makeBudgetViewModel() -> BudgetViewModel {
        let context = PreviewContainer.shared.container.mainContext
        
        let repository = SwiftDataBudgetRepository(modelContext: context)
        
        return BudgetViewModel(repository: repository)
    }
    
    @MainActor
    static func makeBalanceViewModel() -> BalanceViewModel {
        let context = PreviewContainer.shared.container.mainContext
        
        let repository = SwiftDataBalanceRepository(modelContext: context)
        
        return BalanceViewModel(repository: repository)
    }
    
    @MainActor
    static func makeNetWorthViewModel() -> NetWorthViewModel {
        let context = PreviewContainer.shared.container.mainContext
        
        let repository = SwiftDataNetWorthRepository(modelContext: context)
        
        return NetWorthViewModel(repository: repository)
    }
}
