//
//  HabitProfileScreen.swift
//  Habit
//
//  Created by TiniT on 19/5/26.
//

import SwiftUI
import SwiftData
import UIKit
import UniformTypeIdentifiers

struct HabitProfileScreen: View {
    @Environment(HabitProfileRouter.self) private var router
    @Environment(HabitStore.self) private var habitStore
    @State private var backupDocument = HabitBackupDocument()
    @State private var isExportingBackup = false
    @State private var isImportingBackup = false
    @State private var pendingImportData: Data?
    @State private var pendingImportSummary: HabitBackupSummary?
    @State private var showsImportConfirmation = false
    @State private var safetyBackupURLs: [URL] = []
    @State private var backupMessage: BackupMessage?

    var body: some View {
        @Bindable var habitStore = habitStore
        BaseScreen($habitStore.profileTitle) {
            AppScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    settingsSection
                    backupSection
                    frequencyPreviewSection
                }
                .padding(.horizontal)
                .padding(.top, 16)
                .padding(.bottom, 28)
            }
        }
        .shadow(color: .primary.opacity(0.3), radius: 3)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    router.push(.editProfile)
                } label: {
                    avatarView
                }
            }
            .sharedBackgroundVisibility(.hidden)
        }
        .onAppear {
            habitStore.fetchUserProfile()
            safetyBackupURLs = habitStore.safetyBackups()
        }
        .fileExporter(
            isPresented: $isExportingBackup,
            document: backupDocument,
            contentType: .json,
            defaultFilename: "HabitBackup-\(Date().toString(withFormat: .custom("yyyy-MM-dd")))"
        ) { result in
            handleExportResult(result)
        }
        .fileImporter(
            isPresented: $isImportingBackup,
            allowedContentTypes: [.json],
            allowsMultipleSelection: false
        ) { result in
            handleImportSelection(result)
        }
        .confirmationDialog(
            "Import backup?",
            isPresented: $showsImportConfirmation,
            titleVisibility: .visible
        ) {
            Button("Replace Current Data", role: .destructive) {
                importPendingBackup()
            }

            Button("Cancel", role: .cancel) {
                pendingImportData = nil
                pendingImportSummary = nil
            }
        } message: {
            Text(importConfirmationMessage)
        }
        .alert(item: $backupMessage) { message in
            Alert(
                title: Text(message.title),
                message: Text(message.message),
                dismissButton: .default(Text("OK"))
            )
        }
    }

    private var importConfirmationMessage: String {
        guard let pendingImportSummary else {
            return "This will replace your current profile, habits, entries, and reminders with the selected backup."
        }

        return """
        This backup was exported on \(pendingImportSummary.exportedAt.toString(withFormat: .custom("MMM d, yyyy HH:mm"))).

        Profile: \(pendingImportSummary.profileName)
        Habits: \(pendingImportSummary.habitCount)
        Entries: \(pendingImportSummary.entryCount)
        Reminders: \(pendingImportSummary.reminderCount)

        Before replacing current data, the app will save a safety backup of your current data.
        """
    }

    private var currentBackupSummaryMessage: String {
        """
        Habits: \(habitStore.habits.count)
        Entries: \(habitStore.habits.reduce(0) { $0 + $1.entries.count })
        Reminders: \(habitStore.habits.reduce(0) { $0 + $1.reminders.count })
        """
    }

    private var avatarView: some View {
        Group {
            if let avatarData = habitStore.userProfile?.avatarData,
               let uiImage = UIImage(data: avatarData) {
                Image(uiImage: uiImage)
                    .resizable()
                    .scaledToFill()
            } else {
                Image(module: "person.crop.circle.fill")
                    .resizable()
                    .scaledToFit()
                    .foregroundStyle(.secondary)
                    .padding(10)
            }
        }
        .borderedBackground(cornerRadius: 38)
        .frame(width: 46, height: 46)
        .clipShape(Circle())
        .overlay {
            Circle()
                .stroke(Color.primary.opacity(0.12), lineWidth: 1)
        }
    }

    private var settingsSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Preferences")
                .font(.headline)
                .fontDesign(.rounded)

            VStack(spacing: 14) {
                Toggle("Start week on Monday", isOn: Binding(
                    get: { habitStore.weekStartsOnMonday },
                    set: { habitStore.updateWeekStartsOnMonday($0) }
                ))
                .font(.body)
                .fontDesign(.rounded)

                Divider().opacity(0.28)

                VStack(alignment: .leading, spacing: 10) {
                    Text("Appearance")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .fontDesign(.rounded)

                    Picker("Appearance", selection: Binding(
                        get: { habitStore.colorScheme },
                        set: { habitStore.updateColorScheme($0) }
                    )) {
                        ForEach(AppColorScheme.allCases) { colorScheme in
                            Text(colorScheme.title).tag(colorScheme)
                        }
                    }
                    .pickerStyle(.segmented)
                }
            }
            .padding()
            .borderedBackground(cornerRadius: 16)
        }
    }

    private var backupSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Backup")
                .font(.headline)
                .fontDesign(.rounded)

            VStack(spacing: 0) {
                backupButton(
                    title: "Export JSON Backup",
                    subtitle: "Save profile, habits, entries, and reminders",
                    systemImage: "square.and.arrow.up"
                ) {
                    exportBackup()
                }

                Divider()
                    .padding(.leading, 52)

                backupButton(
                    title: "Import JSON Backup",
                    subtitle: "Restore data from a saved backup file",
                    systemImage: "square.and.arrow.down"
                ) {
                    isImportingBackup = true
                }

                if !safetyBackupURLs.isEmpty {
                    Divider()
                        .padding(.leading, 52)

                    Menu {
                        ForEach(safetyBackupURLs, id: \.self) { url in
                            Button(safetyBackupTitle(for: url)) {
                                importSafetyBackup(from: url)
                            }
                        }
                    } label: {
                        backupRow(
                            title: "Restore Safety Backup",
                            subtitle: "Recover data saved before the last import",
                            systemImage: "clock.arrow.circlepath"
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.vertical, 4)
            .borderedBackground(cornerRadius: 16)
        }
    }

    private func backupButton(
        title: String,
        subtitle: String,
        systemImage: String,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            backupRow(title: title, subtitle: subtitle, systemImage: systemImage)
        }
        .buttonStyle(.plain)
    }

    private func backupRow(
        title: String,
        subtitle: String,
        systemImage: String
    ) -> some View {
        HStack(spacing: 14) {
            Image(module: systemImage)
                .font(.title3.weight(.semibold))
                .frame(width: 38, height: 38)
                .background(Color.primary.opacity(0.06))
                .clipShape(RoundedRectangle(cornerRadius: 10))

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.body)
                    .fontWeight(.semibold)
                    .fontDesign(.rounded)

                Text(subtitle)
                    .font(.caption)
                    .fontDesign(.rounded)
                    .foregroundStyle(.secondary)
            }

            Spacer()
        }
        .padding()
    }

    private var frequencyPreviewSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Frequency Preview")
                .font(.headline)
                .fontDesign(.rounded)

            VStack(alignment: .leading, spacing: 12) {
                frequencyRow(title: "Daily", days: habitStore.orderedWeekdays)
                frequencyRow(title: "Weekday", days: [1, 2, 3, 4, 5])
                frequencyRow(title: "Weekend", days: habitStore.weekStartsOnMonday ? [6, 0] : [0, 6])
                frequencyRow(title: "Custom", days: habitStore.orderedWeekdays)
            }
            .padding()
            .borderedBackground(cornerRadius: 16)
        }
    }

    private func frequencyRow(title: String, days: [Int]) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.subheadline)
                .fontWeight(.semibold)
                .fontDesign(.rounded)

            HStack(spacing: 8) {
                ForEach(days, id: \.self) { day in
                    Text(shortWeekdayName(for: day))
                        .font(.caption)
                        .fontWeight(.semibold)
                        .fontDesign(.rounded)
                        .frame(width: 38, height: 32)
                        .background(Color.primary.opacity(0.06))
                        .mask {
                            RoundedRectangle(cornerRadius: 8)
                        }
                        .borderedBackground(cornerRadius: 8)
                }
            }
        }
    }

    private func shortWeekdayName(for weekday: Int) -> String {
        switch weekday {
        case 0: "Sun"
        case 1: "Mon"
        case 2: "Tue"
        case 3: "Wed"
        case 4: "Thu"
        case 5: "Fri"
        case 6: "Sat"
        default: ""
        }
    }

    private func exportBackup() {
        do {
            backupDocument = HabitBackupDocument(data: try habitStore.exportBackupData())
            isExportingBackup = true
        } catch {
            backupMessage = BackupMessage(
                title: "Export Failed",
                message: error.localizedDescription
            )
        }
    }

    private func handleExportResult(_ result: Result<URL, Error>) {
        switch result {
        case .success:
            safetyBackupURLs = habitStore.safetyBackups()
            backupMessage = BackupMessage(
                title: "Export Ready",
                message: currentBackupSummaryMessage
            )
        case .failure(let error):
            backupMessage = BackupMessage(
                title: "Export Failed",
                message: error.localizedDescription
            )
        }
    }

    private func handleImportSelection(_ result: Result<[URL], Error>) {
        do {
            guard let url = try result.get().first else {
                return
            }

            let canAccess = url.startAccessingSecurityScopedResource()
            defer {
                if canAccess {
                    url.stopAccessingSecurityScopedResource()
                }
            }

            let data = try Data(contentsOf: url)
            pendingImportSummary = try habitStore.backupSummary(for: data)
            pendingImportData = data
            showsImportConfirmation = true
        } catch {
            pendingImportData = nil
            pendingImportSummary = nil
            backupMessage = BackupMessage(
                title: "Import Failed",
                message: error.localizedDescription
            )
        }
    }

    private func importPendingBackup() {
        guard let pendingImportData else {
            return
        }

        do {
            try habitStore.importBackupData(pendingImportData)
            self.pendingImportData = nil
            self.pendingImportSummary = nil
            safetyBackupURLs = habitStore.safetyBackups()
            backupMessage = BackupMessage(
                title: "Import Complete",
                message: "Your backup was restored successfully. A safety backup of your previous data was saved inside the app's Backups folder."
            )
        } catch {
            backupMessage = BackupMessage(
                title: "Import Failed",
                message: error.localizedDescription
            )
        }
    }

    private func importSafetyBackup(from url: URL) {
        do {
            let data = try Data(contentsOf: url)
            pendingImportSummary = try habitStore.backupSummary(for: data)
            pendingImportData = data
            showsImportConfirmation = true
        } catch {
            backupMessage = BackupMessage(
                title: "Safety Restore Failed",
                message: error.localizedDescription
            )
        }
    }

    private func safetyBackupTitle(for url: URL) -> String {
        url.deletingPathExtension().lastPathComponent
    }
}

private struct BackupMessage: Identifiable {
    let id = UUID()
    let title: String
    let message: String
}

#Preview {
    HabitProfileScreen()
        .modelContainer(previewContainer)
        .environment(HabitStore(modelContext: previewContainer.mainContext))
        .environment(HabitProfileRouter())
}

private let previewContainer: ModelContainer = {
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    return try! ModelContainer(
        for: Habit.self, HabitEntry.self, HabitReminder.self, UserProfile.self,
        configurations: config
    )
}()
