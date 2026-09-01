import Foundation
import Observation
import Domain
import Utility

@Observable
@MainActor
public final class SpeechProviderSettingsViewModel {
    private let useCase: any SpeechProviderSettingsUseCase
    private let usageUseCase: any GoogleCloudSpeechUsageUseCase
    private var preparationTask: Task<Void, Never>?

    public var selectedProvider: SpeechProvider = .apple
    public var selectedOfflineVietnameseModel: OfflineVietnameseModel = .piperVais1000
    public var googleCloudAPIKey = ""
    public private(set) var selectedGoogleCloudVoice: GoogleCloudVoicePreference = .femaleOne
    public private(set) var googleCloudUsage = GoogleCloudSpeechUsage(characterCount: 0)
    public private(set) var hasGoogleCloudAPIKey = false
    public private(set) var isLoading = false
    public private(set) var isSaving = false
    public private(set) var errorMessage: String?

    public init(
        useCase: any SpeechProviderSettingsUseCase,
        usageUseCase: any GoogleCloudSpeechUsageUseCase
    ) {
        self.useCase = useCase
        self.usageUseCase = usageUseCase
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
                offlineVietnameseModel: selectedOfflineVietnameseModel,
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

    public func selectGoogleCloudVoice(_ voice: GoogleCloudVoicePreference) {
        apply(useCase.saveGoogleCloudVoice(voice))
        errorMessage = nil
    }

    public func refreshUsage() {
        googleCloudUsage = usageUseCase.loadCurrentUsage()
    }

    private func apply(_ settings: SpeechProviderSettings) {
        selectedProvider = settings.provider
        hasGoogleCloudAPIKey = settings.hasGoogleCloudAPIKey
        selectedGoogleCloudVoice = settings.googleCloudVoice
        selectedOfflineVietnameseModel = settings.offlineVietnameseModel
    }
}

private struct SettingsSnapshot: Sendable {
    let settings: SpeechProviderSettings
    let usage: GoogleCloudSpeechUsage
}
