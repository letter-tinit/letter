import Foundation
import SwiftUI

@MainActor
@Observable
final class AppBackupViewModel {
    var exportDocument: AppBackupDocument?
    var pendingImport: AppBackup?
    var isClearDataConfirmationPresented = false
    var toastMessage: ToastMessage?

    private let store: AppBackupStore

    init(store: AppBackupStore) {
        self.store = store
    }

    func prepareExport() {
        do {
            exportDocument = AppBackupDocument(backup: try store.exportBackup())
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

    func confirmImport(habitViewModel: HabitViewModel) {
        guard let pendingImport else { return }
        do {
            try store.importBackup(pendingImport)
            habitViewModel.reloadAfterBackupImport()
            self.pendingImport = nil
            toastMessage = ToastMessage(text: "app.backup.restore.success".localized, type: .success)
        } catch {
            show(error)
        }
    }

    func clearExport() { exportDocument = nil }
    func cancelImport() { pendingImport = nil }

    func clearAllData() {
        do {
            try store.clearAllData()
            toastMessage = ToastMessage(text: "profile.backup.clear.success".localized, type: .success)
        } catch {
            show(error)
        }
    }

    private func show(_ error: Error) {
        toastMessage = ToastMessage(text: error.localizedDescription, type: .failure)
    }
}
