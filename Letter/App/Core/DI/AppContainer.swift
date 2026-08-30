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
    private let habitRepository: ImpHabitRepository
    private let habitNotificationRepository: ImpHabitNotificationRepository
    private let calendarPreferences: CalendarPreferences
    private let isInMemory: Bool

    init(inMemory: Bool = false) {
        isInMemory = inMemory
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
            UserProfile.self,
            BalanceMonth.self
        ])
        let config = ModelConfiguration(
            Self.persistentStoreName,
            schema: schema,
            isStoredInMemoryOnly: inMemory
        )
        modelContainer = try! ModelContainer(for: schema, configurations: config)
        
        mainContext = modelContainer.mainContext
        habitRepository = ImpHabitRepository(modelContext: mainContext)
        habitNotificationRepository = ImpHabitNotificationRepository()
        calendarPreferences = CalendarPreferences()
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
        let repository = ImpBudgetRepository(modelContext: mainContext)
        return BudgetViewModel(useCase: ImpBudgetUseCase(repository: repository))
    }

    func makeBudgetDetailViewModel(budget: Budget) -> BudgetDetailViewModel {
        BudgetDetailViewModel(
            budget: budget,
            useCase: ImpBudgetDetailUseCase(
                repository: ImpBudgetRepository(modelContext: mainContext)
            )
        )
    }

    func makeBalanceViewModel() -> BalanceViewModel {
        let repository = ImpBalanceRepository(modelContext: mainContext)
        return BalanceViewModel(useCase: ImpBalanceUseCase(repository: repository))
    }
    
    func makeNetWorthViewModel() -> NetWorthViewModel {
        let repository = ImpNetWorthRepository(modelContext: mainContext)
        return NetWorthViewModel(useCase: ImpNetWorthUseCase(repository: repository))
    }

    func makeHabitViewModel() -> HabitViewModel {
        HabitViewModel(
            useCase: ImpHabitHomeUseCase(
                repository: habitRepository,
                notifications: habitNotificationRepository
            ),
            calendarPreferences: calendarPreferences
        )
    }

    func makeProfileViewModel() -> ProfileViewModel {
        ProfileViewModel(
            useCase: ImpProfileUseCase(repository: habitRepository),
            backupStore: AppBackupStore(modelContext: mainContext),
            calendarPreferences: calendarPreferences
        )
    }

    func makeCreateHabitViewModel(mode: HabitFormMode) -> CreateHabitViewModel {
        let useCase = ImpHabitFormUseCase(
            repository: habitRepository,
            notifications: habitNotificationRepository
        )
        let sourceID: UUID? = switch mode {
        case .create: nil
        case .edit(let id), .newVersion(let id): id
        }
        let source = sourceID.flatMap { try? useCase.loadHabit(id: $0) }

        return CreateHabitViewModel(
            mode: mode,
            source: source,
            formUseCase: useCase,
            calendarPreferences: calendarPreferences
        )
    }

    func makeHabitDetailViewModel(habitID: UUID) -> HabitDetailViewModel {
        HabitDetailViewModel(
            habitID: habitID,
            useCase: ImpHabitDetailUseCase(
                repository: habitRepository,
                notifications: habitNotificationRepository
            )
        )
    }

    func makeHabitStatisticsViewModel() -> HabitStatisticsViewModel {
        HabitStatisticsViewModel(
            useCase: ImpHabitStatisticsUseCase(repository: habitRepository),
            calendarPreferences: calendarPreferences
        )
    }

    func makeFinanceLockManager() -> FinanceLockManager {
        FinanceLockManager(
            useCase: ImpFinanceLockUseCase(
                repository: ImpFinanceLockRepository()
            )
        )
    }

    func makeAudioBookViewModel() -> AudioBookViewModel {
        let libraryRepository = JSONBookLibraryRepository(inMemory: isInMemory)
        return AudioBookViewModel(
            libraryUseCase: DefaultBookLibraryUseCase(
                repository: libraryRepository,
                importer: EBookImporter()
            ),
            playbackUseCase: DefaultAudioBookPlaybackUseCase(
                engine: AppleSpeechPlaybackEngine()
            ),
            exportUseCase: DefaultAudioBookExportUseCase(
                exporter: AppleBookAudioExporter()
            )
        )
    }
}
