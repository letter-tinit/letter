import Foundation
import Observation
import SwiftUI

@Observable
@MainActor
final class ProfileViewModel {
    private let repository: any HabitRepository
    private let backupStore: AppBackupStore
    private let calendarPreferences: CalendarPreferences

    var profileTitle: String = AppString.ScreenTitle.profile
    private(set) var userProfile: UserProfile?
    private(set) var colorScheme: AppColorScheme
    private(set) var errorMessage: String?

    var exportDocument: AppBackupDocument?
    var pendingImport: AppBackup?
    var toastMessage: ToastMessage?

    var weekStartsOnMonday: Bool {
        calendarPreferences.weekStartsOnMonday
    }

    init(
        repository: any HabitRepository,
        backupStore: AppBackupStore,
        calendarPreferences: CalendarPreferences
    ) {
        self.repository = repository
        self.backupStore = backupStore
        self.calendarPreferences = calendarPreferences
        colorScheme = .light
        reload()
    }

    func reload() {
        do {
            if let profile = try repository.fetchUserProfile() {
                userProfile = profile
            } else {
                let profile = UserProfile()
                repository.addProfile(profile)
                try repository.save()
                userProfile = profile
            }

            syncDerivedSettings()
            errorMessage = nil
        } catch {
            Logger.error("Failed to load user profile: \(error)")
            userProfile = nil
            errorMessage = error.localizedDescription
        }
    }

    func updateWeekStartsOnMonday(_ enabled: Bool) {
        guard ensureProfile() else { return }
        userProfile?.weekStartsOnMonday = enabled
        applyWeekPreference(enabled)
        save()
    }

    func updateColorScheme(_ colorScheme: AppColorScheme) {
        guard ensureProfile() else { return }
        userProfile?.colorScheme = colorScheme
        self.colorScheme = colorScheme
        save()
    }

    func updateProfile(
        displayName: String,
        avatarOriginalData: Data?,
        avatarData: Data?
    ) {
        guard ensureProfile() else { return }
        userProfile?.displayName = displayName
        userProfile?.avatarOriginalData = avatarOriginalData
        userProfile?.avatarData = avatarData
        save()
    }

    func prepareExport() {
        do {
            exportDocument = AppBackupDocument(backup: try backupStore.exportBackup())
        } catch {
            show(error)
        }
    }

    func prepareImport(from url: URL) {
        do {
            let scoped = url.startAccessingSecurityScopedResource()
            defer { if scoped { url.stopAccessingSecurityScopedResource() } }
            let backup = try AppBackupStore.decode(Data(contentsOf: url))
            try backup.validate()
            pendingImport = backup
        } catch {
            show(error)
        }
    }

    func confirmImport(onDataChanged: @escaping () -> Void) {
        guard let pendingImport else { return }
        do {
            try backupStore.importBackup(pendingImport)
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
            try backupStore.clearAllData()
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

    private func save() {
        do {
            try repository.save()
            errorMessage = nil
        } catch {
            repository.rollback()
            Logger.error("Failed to save user profile: \(error)")
            errorMessage = error.localizedDescription
            reload()
        }
    }

    private func show(_ error: Error) {
        toastMessage = ToastMessage(text: error.localizedDescription, type: .failure)
    }
}
