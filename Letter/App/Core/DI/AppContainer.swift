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
import LetterSpeech
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
    private let bookLibraryRepository: any BookLibraryRepository
    private let playbackCheckpointRepository: any PlaybackCheckpointRepository
    private let kokoroSpeechEngine = KokoroSpeechEngine()
    private lazy var audioBookPlayerUseCase = makeAudioBookPlayerUseCase()
    // The shared playback session has one callback owner across SwiftUI view rebuilds.
    private lazy var audioBookPlayerViewModel = AudioBookPlayerViewModel(useCase: audioBookPlayerUseCase)

    init(inMemory: Bool = false) {
        if !inMemory {
            Self.prepareApplicationSupportDirectory()
        }
        bookLibraryRepository = ImpBookLibraryRepository(inMemory: inMemory)
        playbackCheckpointRepository = ImpPlaybackCheckpointRepository(inMemory: inMemory)

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
            : UserDefaultsSpeechProviderSettingsRepository()
    }

    private static func makeOfflineSpeechProviders(
        voice: OfflineSpeechVoice?,
        kokoroEngine: KokoroSpeechEngine
    ) -> LocalSpeechProviderStore {
        let vieNeuSynthesizer = VieNeuSpeechSynthesizer(
            models: BundledVieNeuModels(),
            selectedVoiceID: { voice?.rawValue ?? OfflineSpeechVoice.ngocLinh.rawValue }
        )
        return LocalSpeechProviderStore(
            providers: [
                OfflineSpeechModel.kokoro82M.rawValue: KokoroSpeechSynthesizer(
                    engine: kokoroEngine,
                    voice: voice.flatMap { KokoroVoice(rawValue: $0.rawValue) } ?? .heart
                ),
                OfflineSpeechModel.vieNeuV3Turbo.rawValue: vieNeuSynthesizer,
                OfflineSpeechModel.vieNeuV3Nano.rawValue: VieNeuNanoSpeechSynthesizer(
                    models: BundledVieNeuNanoModels(),
                    selectedVoiceID: { voice?.rawValue ?? OfflineSpeechVoice.adam.rawValue }
                )
            ]
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
        let backupCoordinator = BackupPersistenceCoordinator(
            financePersistence: FinanceBackupPersistence(modelContext: mainContext),
            habitPersistence: HabitBackupPersistence(
                repository: habitRepository,
                notificationRepository: habitNotificationRepository
            ),
            speechProviderSettings: speechProviderSettingsRepository
        )
        return ProfileViewModel(
            useCase: ImpProfileUseCase(
                repository: habitRepository,
                backupRepository: ImpBackupRepository(coordinator: backupCoordinator)
            ),
            calendarPreferences: calendarPreferences,
            voiceSettingsUseCase: ImpSpeechProviderSettingsUseCase(
                repository: speechProviderSettingsRepository
            ),
            appleVoiceCatalog: ImpSystemAppleSpeechVoiceCatalogRepository()
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
        AudioBookViewModel(useCase: makeAudioBookUseCase())
    }

    func makeAudioBookPlayerViewModel() -> AudioBookPlayerViewModel {
        audioBookPlayerViewModel
    }

    private func makeAudioBookPlayerUseCase() -> ImpAudioBookPlayerUseCase {
        let checkpointUseCase = ImpPlaybackCheckpointUseCase(
            repository: playbackCheckpointRepository
        )
        let settings = speechProviderSettingsRepository
        let playbackUseCase = ImpAudioBookPlaybackUseCase(
            settings: settings,
            media: ImpSystemMediaRepository(),
            appleEngine: ImpAppleSpeechPlaybackRepository(),
            offlineEngine: makeOfflineSpeechPlaybackRepository()
        )
        return ImpAudioBookPlayerUseCase(
            libraryUseCase: makeAudioBookUseCase(
                checkpointUseCase: checkpointUseCase
            ),
            playbackUseCase: playbackUseCase,
            checkpointUseCase: checkpointUseCase
        )
    }

    private func makeAudioBookUseCase(
        checkpointUseCase: (any PlaybackCheckpointUseCase)? = nil
    ) -> ImpAudioBookUseCase {
        let checkpointUseCase = checkpointUseCase ?? ImpPlaybackCheckpointUseCase(
            repository: playbackCheckpointRepository
        )
        return ImpAudioBookUseCase(
            repository: bookLibraryRepository,
            importer: ImpEBookImporterRepository(),
            checkpointUseCase: checkpointUseCase
        )
    }

    private func makeOfflineSpeechPlaybackRepository() -> ImpOfflineSpeechPlaybackRepository {
        // Reuse loaded models across chapters; retain only the latest voice's store.
        var cachedVoice: OfflineSpeechVoice?
        var cachedProviders: LocalSpeechProviderStore?
        let kokoroEngine = kokoroSpeechEngine
        return ImpOfflineSpeechPlaybackRepository(
            makeProviders: { voice in
                if voice == cachedVoice, let cachedProviders { return cachedProviders }
                let providers = Self.makeOfflineSpeechProviders(voice: voice, kokoroEngine: kokoroEngine)
                cachedVoice = voice
                cachedProviders = providers
                return providers
            }
        )
    }

}
