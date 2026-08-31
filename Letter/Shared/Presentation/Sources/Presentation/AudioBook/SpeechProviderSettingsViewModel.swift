import Foundation
import Observation
import Domain
import Utility

@Observable
@MainActor
public final class SpeechProviderSettingsViewModel {
    private let useCase: any SpeechProviderSettingsUseCase
    private let usageUseCase: any GoogleCloudSpeechUsageUseCase

    public var selectedProvider: SpeechProvider = .apple
    public var googleCloudAPIKey = ""
    public private(set) var selectedGoogleCloudVoice: GoogleCloudVoicePreference = .femaleOne
    public private(set) var googleCloudUsage = GoogleCloudSpeechUsage(characterCount: 0)
    public private(set) var hasGoogleCloudAPIKey = false
    public private(set) var errorMessage: String?

    public init(
        useCase: any SpeechProviderSettingsUseCase,
        usageUseCase: any GoogleCloudSpeechUsageUseCase
    ) {
        self.useCase = useCase
        self.usageUseCase = usageUseCase
        reload()
    }

    public func reload() {
        apply(useCase.load())
        googleCloudAPIKey = ""
        errorMessage = nil
        refreshUsage()
    }

    public func save() -> Bool {
        do {
            let output = try useCase.save(
                provider: selectedProvider,
                newGoogleCloudAPIKey: googleCloudAPIKey
            )
            apply(output)
            googleCloudAPIKey = ""
            errorMessage = nil
            return true
        } catch SpeechProviderSettingsError.missingGoogleCloudAPIKey {
            errorMessage = "audioBook.speechSettings.error.missingKey".localized
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
    }
}
