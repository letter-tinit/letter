import Foundation
import SwiftData
import Domain
import Utility

@MainActor
public final class ImpHabitRepository: HabitRepository {
    private let modelContext: ModelContext

    public init(modelContext: ModelContext) {
        self.modelContext = modelContext
    }

    public func fetchHabits() throws -> [Habit] {
        try modelContext.fetch(FetchDescriptor<Habit>(
            sortBy: [
                SortDescriptor(\.sortOrder),
                SortDescriptor(\.createdAt, order: .reverse)
            ]
        ))
    }

    public func fetchHabitSnapshots() throws -> [HabitSnapshot] {
        try fetchHabits().map(HabitSnapshotMapper.makeSnapshot)
    }

    public func createHabit(
        from draft: HabitDraft,
        id: UUID,
        createdAt: Date,
        sortOrder: Int
    ) throws -> HabitSnapshot {
        let habit = makeHabit(from: draft)
        habit.id = id
        habit.createdAt = createdAt
        habit.sortOrder = sortOrder
        replaceReminders(for: habit, with: draft.reminders)
        modelContext.insert(habit)
        return try commitAndSnapshot(habit)
    }

    public func updateHabit(
        id: UUID,
        from draft: HabitDraft,
        streak: HabitStreakValues
    ) throws -> HabitSnapshot? {
        guard let habit = try findHabit(id: id) else { return nil }
        apply(draft, to: habit)
        apply(streak, to: habit)
        return try commitAndSnapshot(habit)
    }

    public func deleteHabit(id: UUID) throws -> Bool {
        let habits = try fetchHabits()
        guard let habit = habits.first(where: { $0.id == id }) else { return false }
        modelContext.delete(habit)
        try commit()
        return true
    }

    public func persistEntry(
        _ values: HabitEntryValues,
        habitID: UUID,
        streak: HabitStreakValues
    ) throws -> HabitSnapshot? {
        guard let habit = try findHabit(id: habitID) else { return nil }
        if let entry = habit.entries.first(where: { $0.date == values.date }) {
            entry.completedCount = values.completedCount
            entry.status = values.status
            if let note = values.note { entry.note = note }
            entry.updatedAt = values.updatedAt
        } else {
            let entry = HabitEntry(
                date: values.date,
                completedCount: values.completedCount,
                status: values.status,
                note: values.note ?? ""
            )
            entry.updatedAt = values.updatedAt
            entry.habit = habit
            habit.entries.append(entry)
            modelContext.insert(entry)
        }

        apply(streak, to: habit)
        return try commitAndSnapshot(habit)
    }

    public func fetchUserProfile() throws -> UserProfileSnapshot? {
        try fetchUserProfileRecord().map(makeProfileSnapshot)
    }

    public func createDefaultUserProfile() throws -> UserProfileSnapshot {
        let profile = UserProfile()
        modelContext.insert(profile)
        try commit()
        return makeProfileSnapshot(profile)
    }

    public func updateProfileWeekStart(_ enabled: Bool) throws -> UserProfileSnapshot? {
        guard let profile = try fetchUserProfileRecord() else { return nil }
        profile.weekStartsOnMonday = enabled
        try commit()
        return makeProfileSnapshot(profile)
    }

    public func updateProfileColorScheme(_ colorScheme: AppColorScheme) throws -> UserProfileSnapshot? {
        guard let profile = try fetchUserProfileRecord() else { return nil }
        profile.colorScheme = colorScheme
        try commit()
        return makeProfileSnapshot(profile)
    }

    public func updateProfile(
        displayName: String,
        avatarOriginalData: Data?,
        avatarData: Data?
    ) throws -> UserProfileSnapshot? {
        guard let profile = try fetchUserProfileRecord() else { return nil }
        profile.displayName = displayName
        profile.avatarOriginalData = avatarOriginalData
        profile.avatarData = avatarData
        try commit()
        return makeProfileSnapshot(profile)
    }

    public func fetchUserProfileRecord() throws -> UserProfile? {
        try modelContext.fetch(FetchDescriptor<UserProfile>()).first
    }

    public func fetchUsesCompactStatisticsView() throws -> Bool {
        try fetchUserProfileRecord()?.usesSimplifiedStatisticsMode ?? false
    }

    public func setUsesCompactStatisticsView(_ enabled: Bool) throws {
        guard let profile = try fetchUserProfileRecord() else { return }
        profile.usesSimplifiedStatisticsMode = enabled
        try commit()
    }

    public func addHabit(_ habit: Habit) { modelContext.insert(habit) }
    public func addEntry(_ entry: HabitEntry) { modelContext.insert(entry) }
    public func addReminder(_ reminder: HabitReminder) { modelContext.insert(reminder) }
    public func addProfile(_ profile: UserProfile) { modelContext.insert(profile) }

    public func removeAllHabitData() throws {
        try modelContext.fetch(FetchDescriptor<HabitEntry>()).forEach { modelContext.delete($0) }
        try modelContext.fetch(FetchDescriptor<HabitReminder>()).forEach { modelContext.delete($0) }
        try modelContext.fetch(FetchDescriptor<Habit>()).forEach { modelContext.delete($0) }
        try modelContext.fetch(FetchDescriptor<UserProfile>()).forEach { modelContext.delete($0) }
    }

    public func save() throws {
        guard modelContext.hasChanges else { return }
        try modelContext.save()
    }

    public func rollback() {
        modelContext.rollback()
    }

    private func findHabit(id: UUID) throws -> Habit? {
        try fetchHabits().first { $0.id == id }
    }

    private func makeProfileSnapshot(_ profile: UserProfile) -> UserProfileSnapshot {
        UserProfileSnapshot(
            id: profile.id,
            displayName: profile.displayName,
            avatarOriginalData: profile.avatarOriginalData,
            avatarData: profile.avatarData,
            weekStartsOnMonday: profile.weekStartsOnMonday,
            colorScheme: profile.colorScheme
        )
    }

    private func makeHabit(from draft: HabitDraft) -> Habit {
        Habit(
            name: draft.name,
            description: draft.description,
            icon: draft.icon,
            colorHex: draft.colorHex,
            startDate: draft.startDate,
            endDate: draft.endDate,
            frequency: draft.frequency,
            targetDaysOfWeek: draft.targetDaysOfWeek,
            goalType: draft.goalType,
            goalCount: draft.goalCount,
            goalUnit: draft.goalUnit
        )
    }

    private func apply(_ draft: HabitDraft, to habit: Habit) {
        habit.name = draft.name
        habit.habitDescription = draft.description
        habit.icon = draft.icon
        habit.colorHex = draft.colorHex
        habit.startDate = draft.startDate
        habit.endDate = draft.endDate
        replaceReminders(for: habit, with: draft.reminders)
    }

    private func apply(_ streak: HabitStreakValues, to habit: Habit) {
        habit.currentStreak = streak.current
        habit.longestStreak = streak.longest
        habit.lastCompletedDate = streak.lastCompletedDate
    }

    private func replaceReminders(
        for habit: Habit,
        with configurations: [HabitReminderConfiguration]
    ) {
        habit.reminders.forEach(modelContext.delete)
        habit.reminders.removeAll()

        for configuration in configurations.sorted(by: { $0.time < $1.time }) {
            let reminder = HabitReminder(
                time: configuration.time,
                daysOfWeek: configuration.daysOfWeek,
                isEnabled: configuration.isEnabled
            )
            reminder.id = configuration.id
            reminder.notificationID = configuration.notificationID
            reminder.habit = habit
            habit.reminders.append(reminder)
            modelContext.insert(reminder)
        }
    }

    private func commitAndSnapshot(_ habit: Habit) throws -> HabitSnapshot {
        try commit()
        return HabitSnapshotMapper.makeSnapshot(from: habit)
    }

    private func commit() throws {
        do {
            try save()
        } catch {
            rollback()
            throw error
        }
    }
}

public enum HabitSnapshotMapper {
    public static func makeSnapshot(from habit: Habit) -> HabitSnapshot {
        HabitSnapshot(
            id: habit.id,
            name: habit.name,
            habitDescription: habit.habitDescription,
            icon: habit.icon,
            colorHex: habit.colorHex,
            createdAt: habit.createdAt,
            sortOrder: habit.sortOrder,
            startDate: habit.startDate,
            endDate: habit.endDate,
            frequency: habit.frequency,
            targetDaysOfWeek: habit.targetDaysOfWeek,
            goalType: habit.goalType,
            goalCount: habit.goalCount,
            goalUnit: habit.goalUnit,
            currentStreak: habit.currentStreak,
            longestStreak: habit.longestStreak,
            lastCompletedDate: habit.lastCompletedDate,
            reminders: habit.reminders.map {
                HabitReminderConfiguration(
                    id: $0.id,
                    notificationID: $0.notificationID,
                    time: $0.time,
                    daysOfWeek: $0.daysOfWeek,
                    isEnabled: $0.isEnabled
                )
            },
            entries: habit.entries.map {
                HabitEntrySnapshot(
                    date: $0.date,
                    completedCount: $0.completedCount,
                    status: $0.status
                )
            }
        )
    }
}
