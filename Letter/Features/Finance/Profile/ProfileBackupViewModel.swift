//
//  ProfileBackupViewModel.swift
//  Personal Finance
//
//  Created by Codex on 22/7/26.
//

import Foundation
import SwiftUI
import SwiftData

@MainActor
@Observable
final class ProfileBackupViewModel {
    var exportDocument: PersonalFinanceBackupDocument?
    var toastMessage: ToastMessage?

    private let store: PersonalFinanceBackupStore

    init(modelContext: ModelContext) {
        store = PersonalFinanceBackupStore(modelContext: modelContext)
    }

    func prepareExport() {
        do {
            toastMessage = nil
            exportDocument = PersonalFinanceBackupDocument(backup: try store.exportBackup())
        } catch {
            showError(error.localizedDescription)
        }
    }

    func clearExport() {
        exportDocument = nil
    }

    func importBackup(from url: URL) {
        do {
            toastMessage = nil
            let scoped = url.startAccessingSecurityScopedResource()
            defer {
                if scoped {
                    url.stopAccessingSecurityScopedResource()
                }
            }

            let data = try Data(contentsOf: url)
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            let backup = try decoder.decode(PersonalFinanceBackup.self, from: data)
            try store.importBackup(backup)
            showSuccess("profile.backup.import.success".localized)
        } catch {
            showError(error.localizedDescription)
        }
    }
    
    func makeToastError(_ message: String) {
        showError(message)
    }
}

// MARK: - PRIVATE HELPER
private extension ProfileBackupViewModel {
    func showError(_ text: String) {
        toastMessage = ToastMessage(text: text, type: .failure)
    }
    
    func showSuccess(_ text: String) {
        toastMessage = ToastMessage(text: text, type: .success)
    }
}
