//
//  HabitDetailView.swift
//  Letter
//
//  Created by TiniT on 29/4/26.
//

import SwiftUI

struct HabitDetailView: View {
    @Environment(HabitViewModel.self) private var habitViewModel
    let habitID: UUID
    
    var body: some View {
        Group {
            if let habit = habitViewModel.habit(id: habitID) {
                HabitDetailContentView(habitID: habitID, habit: habit)
            } else {
                CommonEmptyView(description: "habit.detail.noneSelected".localized)
            }
        }
    }
}

private enum HabitDetailSheet: Identifiable {
    case edit
    case newVersion
    
    var id: String {
        switch self {
        case .edit:
            "edit"
        case .newVersion:
            "newVersion"
        }
    }
}

struct HabitDetailContentView: View {
    @Environment(HabitViewModel.self) private var habitViewModel
    @Environment(HabitRouter.self) private var router
    @Environment(\.dismiss) private var dismiss
    
    let habitID: UUID
    var habit: Habit
    
    @FocusState private var isFocused: Bool
    @State private var activeSheet: HabitDetailSheet?
    @State private var showsArchiveConfirmation = false
    @State private var showsDeleteConfirmation = false
    @State private var title: String = "common.detail".localized
    
    var body: some View {
        BaseScreen($title) {
            VStack {
                header
                content
                if !habit.isArchived {
                    startVersionButton
                }
                
                Spacer()
            }
            .padding(.top)
            .listStyle(.insetGrouped)
            .scrollContentBackground(.hidden)
            .scrollIndicators(.hidden)
        }
        // MARK: - ToolBar
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    Button {
                        Haptic.selection()
                        activeSheet = .edit
                    } label: {
                        Label("common.edit".localized, systemImage: "pencil")
                    }

                    Button {
                        Haptic.selection()
                        showsArchiveConfirmation = true
                    } label: {
                        Label(
                            habit.isArchived ? "common.unarchive".localized : "common.archive".localized,
                            systemImage: habit.isArchived
                                ? "tray.and.arrow.up"
                                : "archivebox"
                        )
                    }

                    Divider()

                    Button(role: .destructive) {
                        Haptic.selection()
                        showsDeleteConfirmation = true
                    } label: {
                        Label("common.delete".localized, systemImage: "trash")
                    }
                } label: {
                    Image(systemName: "ellipsis")
                }
            }
        }
        .commonConfirmationDialog(
            isPresented: $showsArchiveConfirmation,
            title: (habit.isArchived ? "habit.unarchive.confirmation" : "habit.archive.confirmation").localized,
            message: (habit.isArchived ? "habit.unarchive.description" : "habit.archive.description").localized,
            actions: [
                ConfirmationDialogAction(
                    (habit.isArchived ? "habit.unarchive.action" : "habit.archive.action").localized,
                    role: habit.isArchived ? nil : .destructive,
                    action: archiveHabit
                ),
                ConfirmationDialogAction("common.cancel".localized, role: .cancel) {}
            ]
        )
        .deleteConfirmationDialog(
            isPresented: $showsDeleteConfirmation,
            title: deleteConfirmationTitle,
            message: deleteConfirmationMessage,
            deleteTitle: (canDeleteSeries ? "habit.delete.version" : "habit.delete.action").localized,
            deleteAction: deleteHabit,
            additionalDeleteActions: canDeleteSeries
            ? [
                ConfirmationDialogAction(
                    "habit.delete.allVersions".localized(seriesHabitCount),
                    role: .destructive,
                    action: deleteHabitSeries
                )
            ]
            : []
        )
        .sheet(item: $activeSheet) { sheet in
            NavigationStack {
                switch sheet {
                case .edit:
                    CreateHabitView(
                        habit: habit,
                        onStartNewVersion: { _ in
                            activeSheet = .newVersion
                        }
                    )
                case .newVersion:
                    CreateHabitView(newVersionOf: habit) { newHabit in
                        activeSheet = nil
                        router.path = [.habitDetail(newHabit.id)]
                    }
                }
            }
        }
    }
    
    private var header: some View {
        // MARK: HEADER
        StandaloneSection {
            HStack(spacing: 14) {
                Button {
                    baseAnimation {
                        isFocused = true
                    }
                } label: {
                    let color = Color(hex: habit.colorHex)
                    Image(module: habit.icon)
                        .padding(16)
                        .scaledToFit()
                        .frame(width: 52, height: 52)
                        .appGlassEffect(
                            .regular.tint(color.opacity(0.2))
                        )
                        .foregroundStyle(color)
                }
                .buttonStyle(.plain)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(habit.name)
                        .customFont(.title3, weight: .semibold)
                    
                    Text(habit.habitDescription.isEmpty ? "common.nil.note".localized : habit.habitDescription)
                        .customFont(.subheadline)
                        .foregroundStyle(.secondary)
                        .lineLimit(3)
                }
                
                Spacer(minLength: 0)
            }
        }
    }
    
    // MARK: CONTENT
    private var content: some View {
        StandaloneSection("common.description".localized) {
            VStack(spacing: 0) {
                detailRow(title: "habit.repeat.title".localized, value: repeatTitle)
                Divider().opacity(0.28)
                detailRow(title: "habit.reminder.title".localized, value: reminderTitle)
                Divider().opacity(0.28)
                detailRow(title: "habit.goal.title".localized, value: goalTitle)
                if shouldShowVersionInfo {
                    Divider().opacity(0.28)
                    detailRow(title: "habit.version.title".localized, value: "habit.version.number".localized(habit.displayVersionNumber))
                }
                if let previousVersion = habitViewModel.previousVersion(for: habit) {
                    Divider().opacity(0.28)
                    detailRow(
                        title: "habit.version.continuesFrom".localized,
                        value: "habit.version.number".localized(previousVersion.displayVersionNumber)
                    )
                }
                if let nextVersion = habitViewModel.nextVersion(after: habit) {
                    Divider().opacity(0.28)
                    detailRow(
                        title: "habit.version.continuedBy".localized,
                        value: "habit.version.number".localized(nextVersion.displayVersionNumber)
                    )
                }
                Divider().opacity(0.28)
                detailRow(title: "habit.statistics.currentStreak".localized, value: "\(habit.currentStreak)")
                Divider().opacity(0.28)
                detailRow(title: "habit.statistics.bestStreak".localized, value: "\(habit.longestStreak)")
                if let archivedAt = habit.archivedAt {
                    Divider().opacity(0.28)
                    detailRow(
                        title: "habit.archive.date".localized,
                        value: archivedAt.toString(withFormat: .custom("MMM d, yyyy"))
                    )
                }
            }
        }
    }
    
    // MARK: START NEW VERSION
    private var startVersionButton: some View {
        StandaloneSection("common.versioning".localized) {
            Button {
                activeSheet = .newVersion
            } label: {
                HStack(spacing: 10) {
                    Image(module: "arrow.triangle.2.circlepath")
                        .customFont(.headline, weight: .semibold)
                    
                    Text("habit.version.start".localized(habit.displayVersionNumber + 1))
                        .customFont(.subheadline, weight: .semibold)
                    
                    Spacer(minLength: 0)
                    
                    Image(module: "chevron.right")
                        .customFont(.caption, weight: .bold)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }
    
    // MARK: Helper
    private var shouldShowVersionInfo: Bool {
        habit.isVersioned ||
        habitViewModel.previousVersion(for: habit) != nil ||
        habitViewModel.nextVersion(after: habit) != nil
    }
    
    private var seriesHabitCount: Int {
        habitViewModel.habitSeries(containing: habit).count
    }
    
    private var canDeleteSeries: Bool {
        seriesHabitCount > 1
    }
    
    private var deleteConfirmationTitle: String {
        (canDeleteSeries ? "habit.delete.version.confirmation" : "habit.delete.confirmation").localized
    }
    
    private var deleteConfirmationMessage: String {
        if canDeleteSeries {
            return "habit.delete.version.description".localized
        }
        
        return "habit.delete.description".localized
    }
    
    private var repeatTitle: String {
        switch habit.frequency {
        case .daily: "habit.repeat.daily".localized
        case .weekday: "habit.repeat.weekdays".localized
        case .weekend: "habit.repeat.weekends".localized
        case .custom: "habit.repeat.custom".localized
        }
    }
    
    private var goalTitle: String {
        habit.goalType == .todo ? "habit.goal.completeOnce".localized : "\(habit.goalCount) \(habit.goalUnit)"
    }
    
    private var reminderTitle: String {
        let enabledReminders = habit.reminders
            .filter(\.isEnabled)
            .sorted { $0.time < $1.time }
        
        guard !enabledReminders.isEmpty else {
            return "habit.common.none".localized
        }
        
        return enabledReminders
            .map { $0.time.toString(withFormat: .custom("HH:mm")) }
            .joined(separator: ", ")
    }
    
    private func archiveHabit() {
        if habit.isArchived {
            habitViewModel.unarchiveHabit(habit)
        } else {
            habitViewModel.archiveHabit(habit)
        }
    }
    
    private func deleteHabit() {
        if habitViewModel.deleteHabit(id: habitID) {
            dismiss()
        }
    }
    
    private func deleteHabitSeries() {
        if habitViewModel.deleteHabitSeries(containing: habit) {
            dismiss()
        }
    }
    
    private func detailRow(title: String, value: String) -> some View {
        HStack {
            Text(title)
                .customFont(.subheadline)
                .foregroundStyle(.secondary)
            
            Spacer()
            
            Text(value)
                .customFont(.subheadline, weight: .semibold)
        }
        .frame(minHeight: 48)
    }
}
