//
//  AppContainer.swift
//  Letter
//
//  Created by TiniT on 20/7/26.
//

import Foundation
import SwiftData

final class AppContainer: AppViewModelFactory {
    private static let persistentStoreName = "Letter"

    let modelContainer: ModelContainer
    private let mainContext: ModelContext
    private let habitRepository: SwiftDataHabitRepository

    init(inMemory: Bool = false) {
        if !inMemory {
            Self.prepareApplicationSupportDirectory()
        }

        let schema = Schema([
            Transaction.self,
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
            ,BalanceMonth.self
        ])
        let config = ModelConfiguration(
            Self.persistentStoreName,
            schema: schema,
            isStoredInMemoryOnly: inMemory
        )
        modelContainer = try! ModelContainer(for: schema, configurations: config)
        
        mainContext = modelContainer.mainContext
        habitRepository = SwiftDataHabitRepository(modelContext: mainContext)
    }

    private static func prepareApplicationSupportDirectory() {
        do {
            let directory = try FileManager.default.url(
                for: .applicationSupportDirectory,
                in: .userDomainMask,
                appropriateFor: nil,
                create: true
            )
            try FileManager.default.createDirectory(
                at: directory,
                withIntermediateDirectories: true
            )
        } catch {
            assertionFailure("Unable to prepare SwiftData directory: \(error)")
        }
    }

    func makeBudgetViewModel() -> BudgetViewModel {
        BudgetViewModel(repository: SwiftDataBudgetRepository(modelContext: mainContext))
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
            repository: habitRepository,
            notificationScheduler: HabitNotificationScheduler()
        )
    }

    func makeHabitStatisticsViewModel() -> HabitStatisticsViewModel {
        HabitStatisticsViewModel(repository: habitRepository)
    }
}
