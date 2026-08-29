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
        
        let repository = ImpBudgetRepository(modelContext: context)
        
        return BudgetViewModel(useCase: ImpBudgetUseCase(repository: repository))
    }
    
    @MainActor
    static func makeBalanceViewModel() -> BalanceViewModel {
        let context = PreviewContainer.shared.container.mainContext
        
        let repository = ImpBalanceRepository(modelContext: context)
        
        return BalanceViewModel(useCase: ImpBalanceUseCase(repository: repository))
    }
    
    @MainActor
    static func makeNetWorthViewModel() -> NetWorthViewModel {
        let context = PreviewContainer.shared.container.mainContext
        
        let repository = ImpNetWorthRepository(modelContext: context)
        
        return NetWorthViewModel(useCase: ImpNetWorthUseCase(repository: repository))
    }
}
