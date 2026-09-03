import Foundation
import Observation
import Domain
import Utility

@Observable
@MainActor
public final class SpeechProviderSettingsViewModel {
    private let useCase: any SpeechProviderSettingsUseCase
    private let usageUseCase: any GoogleCloudSpeechUsageUseCase
    private let appleVoiceCatalog: any AppleSpeechVoiceCatalog
    private var preparationTask: Task<Void, Never>?

    public var selectedProvider: SpeechProvider = .apple
    public var selectedOfflineModels = Dictionary(
        uniqueKeysWithValues: BookLanguage.allCases.map {
            ($0, OfflineSpeechModel.models(for: $0)[0])
        }
    )
    public var googleCloudAPIKey = ""
    public private(set) var selectedAppleVoiceIDs: [BookLanguage: String] = [:]
    public private(set) var availableAppleVoices: [BookLanguage: [AppleSpeechVoice]] = [:]
    public private(set) var selectedGoogleCloudVoices = Dictionary(
        uniqueKeysWithValues: BookLanguage.allCases.map { ($0, GoogleCloudVoicePreference.femaleOne) }
    )
    public private(set) var selectedOfflineVoices: [OfflineSpeechModel: OfflineSpeechVoice] = [
        .vieNeuV3Turbo: .ngocLinh
    ]
    public private(set) var googleCloudUsage = GoogleCloudSpeechUsage(characterCount: 0)
    public private(set) var hasGoogleCloudAPIKey = false
    public private(set) var isLoading = false
    public private(set) var isSaving = false
    public private(set) var errorMessage: String?

    public init(
        useCase: any SpeechProviderSettingsUseCase,
        usageUseCase: any GoogleCloudSpeechUsageUseCase,
        appleVoiceCatalog: any AppleSpeechVoiceCatalog
    ) {
        self.useCase = useCase
        self.usageUseCase = usageUseCase
        self.appleVoiceCatalog = appleVoiceCatalog
    }

    public func prepare() {
        guard preparationTask == nil else { return }
        preparationTask = Task { [weak self] in
            guard let self else { return }
            await reload()
        }
    }

    public func reload() async {
        guard !isLoading else { return }
        isLoading = true
        defer { isLoading = false }
        let useCase = useCase
        let usageUseCase = usageUseCase
        let snapshot = await Task.detached(priority: .userInitiated) {
            SettingsSnapshot(
                settings: useCase.load(),
                usage: usageUseCase.loadCurrentUsage()
            )
        }.value
        apply(snapshot.settings)
        availableAppleVoices = Dictionary(
            uniqueKeysWithValues: BookLanguage.offlineSpeechDisplayOrder.map {
                ($0, appleVoiceCatalog.availableVoices(for: $0))
            }
        )
        googleCloudUsage = snapshot.usage
        googleCloudAPIKey = ""
        errorMessage = nil
    }

    public func save() async -> Bool {
        guard !isSaving else { return false }
        isSaving = true
        defer { isSaving = false }
        do {
            let output = try await useCase.save(
                provider: selectedProvider,
                offlineModels: selectedOfflineModels,
                newGoogleCloudAPIKey: googleCloudAPIKey
            )
            apply(output)
            googleCloudAPIKey = ""
            errorMessage = nil
            return true
        } catch SpeechProviderSettingsError.missingGoogleCloudAPIKey {
            errorMessage = "audioBook.speechSettings.error.missingKey".localized
        } catch SpeechProviderSettingsError.offlineModelUnavailable {
            errorMessage = "audioBook.speechSettings.error.offlineModel".localized
        } catch {
            errorMessage = "audioBook.speechSettings.error.save".localized
        }
        return false
    }

    public func removeGoogleCloudCredential() {
        do {
            apply(try useCase.removeGoogleCloudCredential())
            googleCloudAPIKey = ""
            errorMessage = nil
        } catch {
            errorMessage = "audioBook.speechSettings.error.save".localized
        }
    }

    public func selectedGoogleCloudVoice(for language: BookLanguage) -> GoogleCloudVoicePreference {
        selectedGoogleCloudVoices[language] ?? .femaleOne
    }

    public func selectedAppleVoiceID(for language: BookLanguage) -> String? {
        selectedAppleVoiceIDs[language]
    }

    public func selectAppleVoice(_ voice: AppleSpeechVoice) {
        apply(useCase.saveAppleVoiceID(voice.id, for: voice.language))
        errorMessage = nil
    }

    public func selectGoogleCloudVoice(
        _ voice: GoogleCloudVoicePreference,
        for language: BookLanguage
    ) {
        apply(useCase.saveGoogleCloudVoice(voice, for: language))
        errorMessage = nil
    }

    public func selectedOfflineModel(for language: BookLanguage) -> OfflineSpeechModel {
        selectedOfflineModels[language] ?? OfflineSpeechModel.models(for: language)[0]
    }

    public func selectOfflineModel(_ model: OfflineSpeechModel, for language: BookLanguage) {
        selectedOfflineModels[language] = model
    }

    public func selectedOfflineVoice(for model: OfflineSpeechModel) -> OfflineSpeechVoice? {
        selectedOfflineVoices[model] ?? model.defaultVoice
    }

    public func selectOfflineVoice(_ voice: OfflineSpeechVoice, for model: OfflineSpeechModel) {
        apply(useCase.saveOfflineVoice(voice, for: model))
        errorMessage = nil
    }

    public func refreshUsage() {
        googleCloudUsage = usageUseCase.loadCurrentUsage()
    }

    private func apply(_ settings: SpeechProviderSettings) {
        selectedProvider = settings.provider
        hasGoogleCloudAPIKey = settings.hasGoogleCloudAPIKey
        selectedAppleVoiceIDs = settings.appleVoiceIDs
        selectedGoogleCloudVoices = settings.googleCloudVoices
        selectedOfflineModels = settings.offlineModels
        selectedOfflineVoices = settings.offlineVoices
    }
}

private struct SettingsSnapshot: Sendable {
    let settings: SpeechProviderSettings
    let usage: GoogleCloudSpeechUsage
}
