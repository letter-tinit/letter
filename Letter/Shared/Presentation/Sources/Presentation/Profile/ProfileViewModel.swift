import Foundation
import Observation
import SwiftUI
import Domain
import Utility
import Styleguide

@Observable
@MainActor
public final class ProfileViewModel {
    private let useCase: any ProfileUseCase
    private let calendarPreferences: CalendarPreferences
    private let voiceSettingsUseCase: any SpeechProviderSettingsUseCase
    private let speechUsageUseCase: any GoogleCloudSpeechUsageUseCase
    private let appleVoiceCatalog: any AppleSpeechVoiceCatalog

    public var profileTitle: String = AppString.ScreenTitle.profile
    private(set) var userProfile: UserProfileSnapshot?
    public private(set) var colorScheme: AppColorScheme
    private(set) var errorMessage: String?

    public var exportDocument: BackupDocument?
    public var pendingImport: BackupImport?
    public var toastMessage: ToastMessage?
    public var selectedProvider: SpeechProvider = .apple
    public var selectedOfflineModels = Dictionary(
        uniqueKeysWithValues: BookLanguage.allCases.map { ($0, OfflineSpeechModel.models(for: $0)[0]) }
    )
    public var googleCloudAPIKey = ""
    public private(set) var selectedAppleVoiceIDs: [BookLanguage: String] = [:]
    public private(set) var availableAppleVoices: [BookLanguage: [AppleSpeechVoice]] = [:]
    public private(set) var selectedGoogleCloudVoices = Dictionary(
        uniqueKeysWithValues: BookLanguage.allCases.map { ($0, GoogleCloudVoicePreference.femaleOne) }
    )
    public private(set) var selectedOfflineVoices: [OfflineSpeechModel: OfflineSpeechVoice] = [.vieNeuV3Turbo: .ngocLinh]
    public private(set) var googleCloudUsage = GoogleCloudSpeechUsage(characterCount: 0)
    public private(set) var hasGoogleCloudAPIKey = false
    public private(set) var isLoadingVoiceSettings = false
    public private(set) var isSavingVoiceSettings = false

    public var weekStartsOnMonday: Bool {
        calendarPreferences.weekStartsOnMonday
    }

    public init(
        useCase: any ProfileUseCase,
        calendarPreferences: CalendarPreferences,
        voiceSettingsUseCase: any SpeechProviderSettingsUseCase,
        speechUsageUseCase: any GoogleCloudSpeechUsageUseCase,
        appleVoiceCatalog: any AppleSpeechVoiceCatalog
    ) {
        self.useCase = useCase
        self.calendarPreferences = calendarPreferences
        self.voiceSettingsUseCase = voiceSettingsUseCase
        self.speechUsageUseCase = speechUsageUseCase
        self.appleVoiceCatalog = appleVoiceCatalog
        colorScheme = .light
        reload()
    }

    public func reload() {
        do {
            userProfile = try useCase.loadProfile()
            syncDerivedSettings()
            errorMessage = nil
        } catch {
            Logger.error("Failed to load user profile: \(error)")
            userProfile = nil
            errorMessage = error.localizedDescription
        }
    }

    public func refreshLocalizedText() {
        profileTitle = "profile.tab.title".localized
    }

    public func updateWeekStartsOnMonday(_ enabled: Bool) {
        guard ensureProfile() else { return }
        performUpdate {
            userProfile = try useCase.updateWeekStartsOnMonday(enabled)
            applyWeekPreference(enabled)
        }
    }

    public func updateColorScheme(_ colorScheme: AppColorScheme) {
        guard ensureProfile() else { return }
        performUpdate {
            userProfile = try useCase.updateColorScheme(colorScheme)
            self.colorScheme = colorScheme
        }
    }

    public func updateProfile(
        displayName: String,
        avatarOriginalData: Data?,
        avatarData: Data?
    ) {
        guard ensureProfile() else { return }
        performUpdate {
            userProfile = try useCase.updateProfile(
                displayName: displayName,
                avatarOriginalData: avatarOriginalData,
                avatarData: avatarData
            )
        }
    }

    public func prepareExport() {
        do {
            let backup = try useCase.exportBackup()
            exportDocument = BackupDocument(data: backup.data)
        } catch {
            show(error)
        }
    }

    public func prepareImport(from url: URL) {
        do {
            pendingImport = try useCase.inspectBackup(at: url)
        } catch {
            show(error)
        }
    }

    public func confirmImport(onDataChanged: @escaping () -> Void) {
        guard let pendingImport else { return }
        do {
            try useCase.restoreBackup(pendingImport.data)
            onDataChanged()
            self.pendingImport = nil
            toastMessage = ToastMessage(text: "app.backup.restore.success".localized, type: .success)
        } catch {
            onDataChanged()
            show(error)
        }
    }

    public func clearExport() { exportDocument = nil }
    public func cancelImport() { pendingImport = nil }

    public func clearAllData(onDataChanged: @escaping () -> Void) {
        do {
            try useCase.clearAllData()
            toastMessage = ToastMessage(text: "profile.backup.clear.success".localized, type: .success)
        } catch {
            show(error)
        }
        onDataChanged()
    }

    public func reloadVoiceSettings() async {
        guard !isLoadingVoiceSettings else { return }
        isLoadingVoiceSettings = true
        defer { isLoadingVoiceSettings = false }
        let settingsUseCase = voiceSettingsUseCase
        let usageUseCase = speechUsageUseCase
        let snapshot = await Task.detached(priority: .userInitiated) {
            VoiceSettingsSnapshot(settings: settingsUseCase.load(), usage: usageUseCase.loadCurrentUsage())
        }.value
        applyVoiceSettings(snapshot.settings)
        googleCloudUsage = snapshot.usage
        availableAppleVoices = Dictionary(uniqueKeysWithValues: BookLanguage.offlineSpeechDisplayOrder.map {
            ($0, appleVoiceCatalog.availableVoices(for: $0))
        })
        googleCloudAPIKey = ""
    }

    public func saveVoiceSettings() async -> Bool {
        guard !isSavingVoiceSettings else { return false }
        isSavingVoiceSettings = true
        defer { isSavingVoiceSettings = false }
        do {
            let settings = try await voiceSettingsUseCase.save(
                provider: selectedProvider,
                offlineModels: selectedOfflineModels,
                newGoogleCloudAPIKey: googleCloudAPIKey
            )
            applyVoiceSettings(settings)
            googleCloudAPIKey = ""
            return true
        } catch SpeechProviderSettingsError.missingGoogleCloudAPIKey {
            showVoiceFailure("audioBook.speechSettings.error.missingKey".localized)
        } catch SpeechProviderSettingsError.offlineModelUnavailable {
            showVoiceFailure("audioBook.speechSettings.error.offlineModel".localized)
        } catch {
            showVoiceFailure("audioBook.speechSettings.error.save".localized)
        }
        return false
    }

    public func removeGoogleCloudCredential() {
        do {
            applyVoiceSettings(try voiceSettingsUseCase.removeGoogleCloudCredential())
            googleCloudAPIKey = ""
            toastMessage = ToastMessage(text: "audioBook.speechSettings.keyRemoved".localized, type: .success)
        } catch {
            showVoiceFailure("audioBook.speechSettings.error.save".localized)
        }
    }

    public func selectedGoogleCloudVoice(for language: BookLanguage) -> GoogleCloudVoicePreference {
        selectedGoogleCloudVoices[language] ?? .femaleOne
    }

    public func selectedAppleVoiceID(for language: BookLanguage) -> String? { selectedAppleVoiceIDs[language] }
    public func selectAppleVoice(_ voice: AppleSpeechVoice) {
        applyVoiceSettings(voiceSettingsUseCase.saveAppleVoiceID(voice.id, for: voice.language))
    }
    public func selectGoogleCloudVoice(_ voice: GoogleCloudVoicePreference, for language: BookLanguage) {
        applyVoiceSettings(voiceSettingsUseCase.saveGoogleCloudVoice(voice, for: language))
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
        applyVoiceSettings(voiceSettingsUseCase.saveOfflineVoice(voice, for: model))
    }

    private func applyVoiceSettings(_ settings: SpeechProviderSettings) {
        selectedProvider = settings.provider
        hasGoogleCloudAPIKey = settings.hasGoogleCloudAPIKey
        selectedAppleVoiceIDs = settings.appleVoiceIDs
        selectedGoogleCloudVoices = settings.googleCloudVoices
        selectedOfflineModels = settings.offlineModels
        selectedOfflineVoices = settings.offlineVoices
    }

    private func showVoiceFailure(_ message: String) {
        toastMessage = ToastMessage(text: message, type: .failure)
    }

    private func ensureProfile() -> Bool {
        if userProfile == nil { reload() }
        return userProfile != nil
    }

    private func syncDerivedSettings() {
        let weekStartsOnMonday = userProfile?.weekStartsOnMonday ?? true
        colorScheme = userProfile?.colorScheme ?? .light
        applyWeekPreference(weekStartsOnMonday)
    }

    private func applyWeekPreference(_ enabled: Bool) {
        calendarPreferences.update(weekStartsOnMonday: enabled)
    }

    private func performUpdate(_ update: () throws -> Void) {
        do {
            try update()
            errorMessage = nil
        } catch {
            Logger.error("Failed to save user profile: \(error)")
            errorMessage = error.localizedDescription
            reload()
        }
    }

    private func show(_ error: Error) {
        let message: String
        switch error {
        case BackupError.unsupportedSchemaVersion(let version):
            message = "app.backup.error.unsupportedVersion".localized(version)
        case BackupError.invalidData:
            message = "profile.backup.error.invalidFile".localized
        case BackupError.restoreFailed:
            message = "app.backup.error.restore".localized
        default:
            message = error.localizedDescription
        }
        toastMessage = ToastMessage(text: message, type: .failure)
    }
}

private struct VoiceSettingsSnapshot: Sendable {
    let settings: SpeechProviderSettings
    let usage: GoogleCloudSpeechUsage
}
