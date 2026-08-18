//
//  AppContainer.swift
//  Personal Finance
//
//  Created by TiniT on 20/7/26.
//

import SwiftData

final class AppContainer: AppViewModelFactory {

    let modelContainer: ModelContainer
    private let mainContext: ModelContext

    init(inMemory: Bool = false) {
        let schema = Schema([
            Transaction.self,
            NetWorthYear.self,
            NetWorthPlanItem.self,
            NetWorthSnapshot.self,
            NetWorthValue.self,
            Budget.self,
            BudgetAllocation.self,
            FixedExpensePlan.self,
            BudgetTransaction.self,
            Habit.self,
            HabitEntry.self,
            HabitReminder.self,
            UserProfile.self
        ])
        let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: inMemory)
        modelContainer = try! ModelContainer(for: schema, configurations: config)
        
        mainContext = modelContainer.mainContext
    }

    func makeBudgetViewModel() -> BudgetViewModel {
        BudgetViewModel(
            repository: ImplBudgetRepository(modelContext: mainContext),
            balanceRepository: ImplBalanceRepository(modelContext: mainContext)
        )
    }

    func makeBudgetDetailViewModel(budget: Budget) -> BudgetDetailViewModel {
        BudgetDetailViewModel(
            budget: budget,
            repository: ImplBudgetRepository(modelContext: mainContext)
        )
    }

    func makeBalanceViewModel() -> BalanceViewModel {
        BalanceViewModel(repository: ImplBalanceRepository(modelContext: mainContext))
    }
    
    func makeNetWorthViewModel() -> NetWorthViewModel {
        NetWorthViewModel(repository: ImplNetWorthRepository(modelContext: mainContext))
    }

    func makeProfileBackupViewModel() -> ProfileBackupViewModel {
        ProfileBackupViewModel(modelContext: mainContext)
    }
}
