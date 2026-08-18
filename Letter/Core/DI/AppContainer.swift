//
//  AppContainer.swift
//  Letter
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
            repository: SwiftDataBudgetRepository(modelContext: mainContext),
            balanceRepository: SwiftDataBalanceRepository(modelContext: mainContext)
        )
    }

    func makeBudgetDetailViewModel(budget: Budget) -> BudgetDetailViewModel {
        BudgetDetailViewModel(
            budget: budget,
            repository: SwiftDataBudgetRepository(modelContext: mainContext)
        )
    }

    func makeBalanceViewModel() -> BalanceViewModel {
        BalanceViewModel(repository: SwiftDataBalanceRepository(modelContext: mainContext))
    }
    
    func makeNetWorthViewModel() -> NetWorthViewModel {
        NetWorthViewModel(repository: SwiftDataNetWorthRepository(modelContext: mainContext))
    }

    func makeAppBackupViewModel() -> AppBackupViewModel {
        AppBackupViewModel(store: AppBackupStore(modelContext: mainContext))
    }

    func makeHabitViewModel() -> HabitViewModel {
        HabitViewModel(
            repository: SwiftDataHabitRepository(modelContext: mainContext),
            notificationScheduler: HabitNotificationScheduler()
        )
    }
}
