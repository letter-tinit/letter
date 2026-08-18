//
//  PreviewHelper.swift
//  Personal Finance
//
//  Created by TiniT on 20/7/26.
//

import SwiftData

struct PreviewHelper {
    @MainActor
    static func makeBudgetViewModel() -> BudgetViewModel {
        let context = PreviewContainer.shared.container.mainContext
        
        let repository = ImplBudgetRepository(modelContext: context)
        
        let balanceRepository = ImplBalanceRepository(modelContext: context)
        
        return BudgetViewModel(repository: repository, balanceRepository: balanceRepository)
    }
    
    @MainActor
    static func makeBalanceViewModel() -> BalanceViewModel {
        let context = PreviewContainer.shared.container.mainContext
        
        let repository = ImplBalanceRepository(modelContext: context)
        
        return BalanceViewModel(repository: repository)
    }
    
    @MainActor
    static func makeNetWorthViewModel() -> NetWorthViewModel {
        let context = PreviewContainer.shared.container.mainContext
        
        let repository = ImplNetWorthRepository(modelContext: context)
        
        return NetWorthViewModel(repository: repository)
    }
}
