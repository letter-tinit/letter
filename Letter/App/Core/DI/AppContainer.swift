//
//  AppContainer.swift
//  Letter
//
//  Created by TiniT on 20/7/26.
//

import Foundation
import SwiftData
import Domain
import Data
import Presentation
import Utility

final class AppContainer: AppViewModelFactory {
    private static let persistentStoreName = "Letter"

    let modelContainer: ModelContainer
    private let mainContext: ModelContext
    private let habitRepository: ImpHabitRepository
    private let habitNotificationRepository: ImpHabitNotificationRepository
    private let calendarPreferences: CalendarPreferences
    private let speechProviderSettingsRepository: any SpeechProviderSettingsRepository
    private let googleCloudSpeechUsageRepository: any GoogleCloudSpeechUsageRepository
    private let localSpeechSynthesizer: any LocalSpeechSynthesizing
    private let isInMemory: Bool

    init(inMemory: Bool = false) {
        isInMemory = inMemory
        if !inMemory {
            Self.prepareApplicationSupportDirectory()
        }

        let schema = Schema([
            TransactionRecord.self,
            NetWorthPlanItemRecord.self,
            NetWorthSnapshotRecord.self,
            NetWorthValueRecord.self,
            BudgetRecord.self,
            BudgetAllocationRecord.self,
            FixedExpensePlanRecord.self,
            BudgetTransactionRecord.self,
            Habit.self,
            HabitEntry.self,
            HabitReminder.self,
            UserProfile.self,
            BalanceMonthRecord.self
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
        speechProviderSettingsRepository = inMemory
            ? InMemorySpeechProviderSettingsRepository()
            : KeychainSpeechProviderSettingsRepository()
        googleCloudSpeechUsageRepository = inMemory
            ? InMemoryGoogleCloudSpeechUsageRepository()
            : UserDefaultsGoogleCloudSpeechUsageRepository()
        let bundledModels = BundledSherpaOnnxModels()
        localSpeechSynthesizer = SherpaOnnxSpeechSynthesizer(
            paths: bundledModels.paths
        )
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
            useCase: ImpProfileUseCase(
                repository: habitRepository,
                backupRepository: ImpBackupRepository(modelContext: mainContext)
            ),
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
        let libraryRepository = ImpBookLibraryRepository(inMemory: isInMemory)
        let checkpointUseCase = ImpPlaybackCheckpointUseCase(
            repository: ImpPlaybackCheckpointRepository(inMemory: isInMemory)
        )
        let googleClient = GoogleCloudTextToSpeechClient(
            settings: speechProviderSettingsRepository,
            usage: googleCloudSpeechUsageRepository
        )
        let playbackEngine = SpeechPlaybackEngineRouter(
            settings: speechProviderSettingsRepository,
            appleEngine: AppleSpeechPlaybackEngine(),
            googleEngine: GoogleCloudSpeechPlaybackEngine(client: googleClient),
            offlineEngine: OfflineSpeechPlaybackEngine(
                synthesizer: localSpeechSynthesizer
            )
        )
        let audioExporter = BookAudioExporterRouter(
            settings: speechProviderSettingsRepository,
            appleExporter: AppleBookAudioExporter(),
            googleExporter: GoogleCloudBookAudioExporter(client: googleClient)
        )
        return AudioBookViewModel(
            libraryUseCase: ImpBookLibraryUseCase(
                repository: libraryRepository,
                importer: EBookImporter(),
                checkpointUseCase: checkpointUseCase
            ),
            playbackUseCase: ImpAudioBookPlaybackUseCase(engine: playbackEngine),
            exportUseCase: ImpAudioBookExportUseCase(
                exporter: audioExporter
            ),
            checkpointUseCase: checkpointUseCase
        )
    }

    func makeSpeechProviderSettingsViewModel() -> SpeechProviderSettingsViewModel {
        SpeechProviderSettingsViewModel(
            useCase: ImpSpeechProviderSettingsUseCase(
                repository: speechProviderSettingsRepository
            ),
            usageUseCase: ImpGoogleCloudSpeechUsageUseCase(
                repository: googleCloudSpeechUsageRepository
            )
        )
    }
}
