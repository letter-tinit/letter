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
    private let offlineSpeechSynthesizer: OfflineSpeechSynthesizerRouter
    private let bookLibraryRepository: any BookLibraryRepository
    private let playbackCheckpointRepository: any PlaybackCheckpointRepository
    private lazy var audioBookPlayerUseCase = makeAudioBookPlayerUseCase()

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
            : KeychainSpeechProviderSettingsRepository()
        googleCloudSpeechUsageRepository = inMemory
            ? ImpInMemoryGoogleCloudSpeechUsageRepository()
            : ImpGoogleCloudSpeechUsageRepository()
        let sherpaSynthesizer = SherpaOnnxSpeechSynthesizer(
            models: BundledSherpaOnnxModels()
        )
        let vieNeuSynthesizer = VieNeuSpeechSynthesizer(
                models: BundledVieNeuModels(),
                selectedVoice: { [speechProviderSettingsRepository] in
                    speechProviderSettingsRepository.loadOfflineVoice(
                        for: .vieNeuV3Turbo
                    ) ?? .ngocLinh
                }
        )
        offlineSpeechSynthesizer = OfflineSpeechSynthesizerRouter(
            settings: speechProviderSettingsRepository,
            synthesizers: [
                .matchaLJSpeech: sherpaSynthesizer,
                .piperVais1000: sherpaSynthesizer,
                .vieNeuV3Turbo: vieNeuSynthesizer,
                .vieNeuV3Nano: VieNeuNanoSpeechSynthesizer(
                    models: BundledVieNeuNanoModels(),
                    selectedVoice: { [speechProviderSettingsRepository] in
                        speechProviderSettingsRepository.loadOfflineVoice(for: .vieNeuV3Nano) ?? .adam
                    }
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
        ProfileViewModel(
            useCase: ImpProfileUseCase(
                repository: habitRepository,
                backupRepository: ImpBackupRepository(
                    modelContext: mainContext,
                    speechProviderSettings: speechProviderSettingsRepository
                )
            ),
            calendarPreferences: calendarPreferences,
            voiceSettingsUseCase: ImpSpeechProviderSettingsUseCase(
                repository: speechProviderSettingsRepository,
                offlineSpeech: offlineSpeechSynthesizer
            ),
            speechUsageUseCase: ImpGoogleCloudSpeechUsageUseCase(
                repository: googleCloudSpeechUsageRepository
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
        AudioBookPlayerViewModel(useCase: audioBookPlayerUseCase)
    }

    func makeAudioBookDetailViewModel() -> AudioBookDetailViewModel {
        let googleClient = GoogleCloudTextToSpeechClient(
            settings: speechProviderSettingsRepository,
            usage: googleCloudSpeechUsageRepository
        )
        let exporter = ImpBookAudioExporterRouterRepository(
            settings: speechProviderSettingsRepository,
            appleExporter: ImpAppleBookAudioExporterRepository(),
            googleExporter: ImpGoogleCloudBookAudioExporterRepository(client: googleClient)
        )
        return AudioBookDetailViewModel(
            useCase: ImpAudioBookDetailUseCase(
                audioBookUseCase: makeAudioBookUseCase(),
                exportUseCase: ImpAudioBookExportUseCase(exporter: exporter),
                playbackRateProvider: audioBookPlayerUseCase
            )
        )
    }

    private func makeAudioBookPlayerUseCase() -> ImpAudioBookPlayerUseCase {
        let checkpointUseCase = ImpPlaybackCheckpointUseCase(
            repository: playbackCheckpointRepository
        )
        let googleClient = GoogleCloudTextToSpeechClient(
            settings: speechProviderSettingsRepository,
            usage: googleCloudSpeechUsageRepository
        )
        let playbackEngine = ImpSpeechPlaybackEngineRouterRepository(
            settings: speechProviderSettingsRepository,
            appleEngine: ImpAppleSpeechPlaybackRepository(settings: speechProviderSettingsRepository),
            googleEngine: ImpGoogleCloudSpeechPlaybackRepository(client: googleClient),
            offlineEngine: ImpOfflineSpeechPlaybackRepository(
                synthesizer: offlineSpeechSynthesizer
            )
        )
        return ImpAudioBookPlayerUseCase(
            libraryUseCase: makeAudioBookUseCase(
                checkpointUseCase: checkpointUseCase
            ),
            playbackUseCase: ImpAudioBookPlaybackUseCase(engine: playbackEngine),
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

}
