//
//  HabitDetailScreen.swift
//  Habit
//
//  Created by TiniT on 29/4/26.
//

import SwiftUI

struct HabitDetailScreen: View {
    @Environment(HabitStore.self) private var habitStore
    let habitID: UUID

    var body: some View {
        Group {
            if let habit = habitStore.habit(id: habitID) {
                HabitDetailContent(habitID: habitID, habit: habit)
            } else {
                Text("No habit selected")
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

struct HabitDetailContent: View {
    @Environment(HabitStore.self) private var habitStore
    @Environment(HomeRouter.self) private var router
    @Environment(\.dismiss) private var dismiss
    let habitID: UUID
    @Bindable var habit: Habit
    @FocusState private var isFocused: Bool
    @State private var activeSheet: HabitDetailSheet?
    @State private var showsArchiveConfirmation = false
    @State private var showsDeleteConfirmation = false

    var body: some View {
        BaseScreen($habit.name) {
            AppScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    HStack(spacing: 14) {
                        Button {
                            baseAnimation {
                                isFocused = true
                            }
                        } label: {
                            Image(module: habit.icon)
                                .padding(16)
                                .scaledToFit()
                                .frame(width: 72, height: 72)
                                .borderedBackground(cornerRadius: 24)
                        }
                        .buttonStyle(.plain)

                        VStack(alignment: .leading, spacing: 6) {
                            Text(habit.name)
                                .font(.title3)
                                .fontWeight(.semibold)
                                .fontDesign(.rounded)

                            Text(habit.habitDescription.isEmpty ? "No description" : habit.habitDescription)
                                .font(.subheadline)
                                .fontDesign(.rounded)
                                .foregroundStyle(.secondary)
                                .lineLimit(3)
                        }

                        Spacer(minLength: 0)
                    }
                    .padding()
                    .borderedBackground(cornerRadius: 24)

                    VStack(spacing: 0) {
                        detailRow(title: "Repeat", value: repeatTitle)
                        Divider().opacity(0.28)
                        detailRow(title: "Reminders", value: reminderTitle)
                        Divider().opacity(0.28)
                        detailRow(title: "Goal", value: goalTitle)
                        if shouldShowVersionInfo {
                            Divider().opacity(0.28)
                            detailRow(title: "Version", value: "Version \(habit.displayVersionNumber)")
                        }
                        if let previousVersion = habitStore.previousVersion(for: habit) {
                            Divider().opacity(0.28)
                            detailRow(
                                title: "Continues from",
                                value: "Version \(previousVersion.displayVersionNumber)"
                            )
                        }
                        if let nextVersion = habitStore.nextVersion(after: habit) {
                            Divider().opacity(0.28)
                            detailRow(
                                title: "Continued by",
                                value: "Version \(nextVersion.displayVersionNumber)"
                            )
                        }
                        Divider().opacity(0.28)
                        detailRow(title: "Current streak", value: "\(habit.currentStreak)")
                        Divider().opacity(0.28)
                        detailRow(title: "Best streak", value: "\(habit.longestStreak)")
                        if let archivedAt = habit.archivedAt {
                            Divider().opacity(0.28)
                            detailRow(
                                title: "Archived on",
                                value: archivedAt.toString(withFormat: .custom("MMM d, yyyy"))
                            )
                        }
                    }
                    .padding(.horizontal)
                    .borderedBackground(cornerRadius: 20)

                    if !habit.isArchived {
                        startVersionButton
                    }
                }
                .padding()
            }
        }
        // MARK: - ToolBar
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    activeSheet = .edit
                } label: {
                    Image(module: "pencil")
                }
            }

            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    showsArchiveConfirmation = true
                } label: {
                    Image(module: habit.isArchived ? "tray.and.arrow.up" : "archivebox")
                }
            }

            ToolbarItem(placement: .topBarTrailing) {
                Button(role: .destructive) {
                    showsDeleteConfirmation = true
                } label: {
                    Image(module: "trash")
                }
            }
        }
        .confirmationDialog(
            habit.isArchived ? "Unarchive habit?" : "Archive habit?",
            isPresented: $showsArchiveConfirmation,
            titleVisibility: .visible
        ) {
            Button(habit.isArchived ? "Unarchive Habit" : "Archive Habit", role: habit.isArchived ? nil : .destructive) {
                archiveHabit()
            }

            Button("Cancel", role: .cancel) {}
        } message: {
            if habit.isArchived {
                Text("This habit will return to your active habit list.")
            } else {
                Text("This habit will be hidden from future days, but existing history will be kept.")
            }
        }
        .confirmationDialog(
            deleteConfirmationTitle,
            isPresented: $showsDeleteConfirmation,
            titleVisibility: .visible
        ) {
            if canDeleteSeries {
                Button("Delete This Version", role: .destructive) {
                    deleteHabit()
                }

                Button("Delete All \(seriesHabitCount) Versions", role: .destructive) {
                    deleteHabitSeries()
                }
            } else {
                Button("Delete Habit", role: .destructive) {
                    deleteHabit()
                }
            }

            Button("Cancel", role: .cancel) {}
        } message: {
            Text(deleteConfirmationMessage)
        }
        .sheet(item: $activeSheet) { sheet in
            NavigationStack {
                switch sheet {
                case .edit:
                    CreateHabitScreen(
                        habit: habit,
                        onStartNewVersion: { _ in
                            activeSheet = .newVersion
                        }
                    )
                case .newVersion:
                    CreateHabitScreen(newVersionOf: habit) { newHabit in
                        activeSheet = nil
                        router.path = [.habitDetail(newHabit.id)]
                    }
                }
            }
        }
    }

    private var shouldShowVersionInfo: Bool {
        habit.isVersioned ||
        habitStore.previousVersion(for: habit) != nil ||
        habitStore.nextVersion(after: habit) != nil
    }

    private var seriesHabitCount: Int {
        habitStore.habitSeries(containing: habit).count
    }

    private var canDeleteSeries: Bool {
        seriesHabitCount > 1
    }

    private var deleteConfirmationTitle: String {
        canDeleteSeries ? "Delete habit version?" : "Delete habit?"
    }

    private var deleteConfirmationMessage: String {
        if canDeleteSeries {
            return "Delete only this version or delete all versions in this habit series. This cannot be undone."
        }

        return "This permanently deletes the habit, entries, reminders, and history. This cannot be undone."
    }

    private var startVersionButton: some View {
        Button {
            activeSheet = .newVersion
        } label: {
            HStack(spacing: 10) {
                Image(module: "arrow.triangle.2.circlepath")
                    .font(.headline)

                Text("Start Version \(habit.displayVersionNumber + 1)")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .fontDesign(.rounded)

                Spacer(minLength: 0)

                Image(module: "chevron.right")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal)
            .frame(maxWidth: .infinity, minHeight: 52)
            .contentShape(RoundedRectangle(cornerRadius: 16))
        }
        .buttonStyle(.plain)
        .borderedBackground(cornerRadius: 16)
    }

    private var repeatTitle: String {
        switch habit.frequency {
        case .daily: "Daily"
        case .weekday: "Weekdays"
        case .weekend: "Weekends"
        case .custom: "Custom"
        }
    }

    private var goalTitle: String {
        habit.goalType == .todo ? "Complete once" : "\(habit.goalCount) \(habit.goalUnit)"
    }

    private var reminderTitle: String {
        let enabledReminders = habit.reminders
            .filter(\.isEnabled)
            .sorted { $0.time < $1.time }

        guard !enabledReminders.isEmpty else {
            return "None"
        }

        return enabledReminders
            .map { $0.time.toString(withFormat: .custom("HH:mm")) }
            .joined(separator: ", ")
    }

    private func archiveHabit() {
        if habit.isArchived {
            habitStore.unarchiveHabit(habit)
        } else {
            habitStore.archiveHabit(habit)
        }
    }

    private func deleteHabit() {
        if habitStore.deleteHabit(id: habitID) {
            dismiss()
        }
    }

    private func deleteHabitSeries() {
        if habitStore.deleteHabitSeries(containing: habit) {
            dismiss()
        }
    }

    private func detailRow(title: String, value: String) -> some View {
        HStack {
            Text(title)
                .font(.subheadline)
                .fontDesign(.rounded)
                .foregroundStyle(.secondary)

            Spacer()

            Text(value)
                .font(.subheadline)
                .fontWeight(.semibold)
                .fontDesign(.rounded)
        }
        .frame(minHeight: 48)
    }
}
