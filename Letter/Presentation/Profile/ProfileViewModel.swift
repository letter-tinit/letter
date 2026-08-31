import Foundation
import Observation
import SwiftUI

@Observable
@MainActor
final class ProfileViewModel {
    private let useCase: any ProfileUseCase
    private let calendarPreferences: CalendarPreferences

    var profileTitle: String = AppString.ScreenTitle.profile
    private(set) var userProfile: UserProfileSnapshot?
    private(set) var colorScheme: AppColorScheme
    private(set) var errorMessage: String?

    var exportDocument: BackupDocument?
    var pendingImport: BackupImport?
    var toastMessage: ToastMessage?

    var weekStartsOnMonday: Bool {
        calendarPreferences.weekStartsOnMonday
    }

    init(
        useCase: any ProfileUseCase,
        calendarPreferences: CalendarPreferences
    ) {
        self.useCase = useCase
        self.calendarPreferences = calendarPreferences
        colorScheme = .light
        reload()
    }

    func reload() {
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

    func refreshLocalizedText() {
        profileTitle = "profile.tab.title".localized
    }

    func updateWeekStartsOnMonday(_ enabled: Bool) {
        guard ensureProfile() else { return }
        performUpdate {
            userProfile = try useCase.updateWeekStartsOnMonday(enabled)
            applyWeekPreference(enabled)
        }
    }

    func updateColorScheme(_ colorScheme: AppColorScheme) {
        guard ensureProfile() else { return }
        performUpdate {
            userProfile = try useCase.updateColorScheme(colorScheme)
            self.colorScheme = colorScheme
        }
    }

    func updateProfile(
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

    func prepareExport() {
        do {
            let backup = try useCase.exportBackup()
            exportDocument = BackupDocument(data: backup.data)
        } catch {
            show(error)
        }
    }

    func prepareImport(from url: URL) {
        do {
            pendingImport = try useCase.inspectBackup(at: url)
        } catch {
            show(error)
        }
    }

    func confirmImport(onDataChanged: @escaping () -> Void) {
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

    func clearExport() { exportDocument = nil }
    func cancelImport() { pendingImport = nil }

    func clearAllData(onDataChanged: @escaping () -> Void) {
        do {
            try useCase.clearAllData()
            toastMessage = ToastMessage(text: "profile.backup.clear.success".localized, type: .success)
        } catch {
            show(error)
        }
        onDataChanged()
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
