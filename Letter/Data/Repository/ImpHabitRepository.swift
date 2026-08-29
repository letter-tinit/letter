import Foundation
import SwiftData

@MainActor
final class ImpHabitRepository: HabitRepository {
    private let modelContext: ModelContext

    init(modelContext: ModelContext) {
        self.modelContext = modelContext
    }

    func fetchHabits() throws -> [Habit] {
        try modelContext.fetch(FetchDescriptor<Habit>(
            sortBy: [
                SortDescriptor(\.sortOrder),
                SortDescriptor(\.createdAt, order: .reverse)
            ]
        ))
    }

    func fetchHabitSnapshots() throws -> [HabitSnapshot] {
        try fetchHabits().map(HabitSnapshotMapper.makeSnapshot)
    }

    func createHabit(
        from draft: HabitDraft,
        id: UUID,
        createdAt: Date,
        sortOrder: Int
    ) throws -> HabitSnapshot {
        let habit = makeHabit(from: draft)
        habit.id = id
        habit.createdAt = createdAt
        habit.seriesID = id
        habit.sortOrder = sortOrder
        replaceReminders(for: habit, with: draft.reminders)
        modelContext.insert(habit)
        return try commitAndSnapshot(habit)
    }

    func updateHabit(
        id: UUID,
        from draft: HabitDraft,
        streak: HabitStreakValues
    ) throws -> HabitSnapshot? {
        guard let habit = try findHabit(id: id) else { return nil }
        apply(draft, to: habit)
        apply(streak, to: habit)
        return try commitAndSnapshot(habit)
    }

    func createHabitVersion(
        replacing sourceID: UUID,
        from draft: HabitDraft,
        id: UUID,
        createdAt: Date,
        startDate: Date,
        sourceEndDate: Date,
        versionNumber: Int,
        streak: HabitStreakValues
    ) throws -> HabitSnapshot? {
        guard let source = try findHabit(id: sourceID) else { return nil }
        source.endDate = sourceEndDate
        source.archivedAt = createdAt
        apply(streak, to: source)

        let habit = makeHabit(from: draft)
        habit.id = id
        habit.createdAt = createdAt
        habit.startDate = startDate
        habit.seriesID = source.effectiveSeriesID
        habit.replacedHabitID = source.id
        habit.versionNumber = versionNumber
        habit.sortOrder = source.sortOrder
        replaceReminders(for: habit, with: draft.reminders)
        modelContext.insert(habit)
        return try commitAndSnapshot(habit)
    }

    func setHabitArchived(_ archived: Bool, id: UUID, at date: Date) throws -> HabitSnapshot? {
        guard let habit = try findHabit(id: id) else { return nil }
        habit.archivedAt = archived ? date : nil
        return try commitAndSnapshot(habit)
    }

    func deleteHabit(id: UUID, reconnectingTo replacementID: UUID?) throws -> Bool {
        let habits = try fetchHabits()
        guard let habit = habits.first(where: { $0.id == id }) else { return false }
        habits
            .filter { $0.replacedHabitID == id }
            .forEach { $0.replacedHabitID = replacementID }
        modelContext.delete(habit)
        try commit()
        return true
    }

    func deleteHabits(ids: Set<UUID>) throws {
        try fetchHabits()
            .filter { ids.contains($0.id) }
            .forEach(modelContext.delete)
        try commit()
    }

    func fetchUserProfile() throws -> UserProfile? {
        try modelContext.fetch(FetchDescriptor<UserProfile>()).first
    }

    func addHabit(_ habit: Habit) { modelContext.insert(habit) }
    func removeHabit(_ habit: Habit) { modelContext.delete(habit) }
    func addEntry(_ entry: HabitEntry) { modelContext.insert(entry) }
    func addReminder(_ reminder: HabitReminder) { modelContext.insert(reminder) }
    func removeReminder(_ reminder: HabitReminder) { modelContext.delete(reminder) }
    func addProfile(_ profile: UserProfile) { modelContext.insert(profile) }

    func removeAllHabitData() throws {
        try modelContext.fetch(FetchDescriptor<HabitEntry>()).forEach { modelContext.delete($0) }
        try modelContext.fetch(FetchDescriptor<HabitReminder>()).forEach { modelContext.delete($0) }
        try modelContext.fetch(FetchDescriptor<Habit>()).forEach { modelContext.delete($0) }
        try modelContext.fetch(FetchDescriptor<UserProfile>()).forEach { modelContext.delete($0) }
    }

    func save() throws {
        guard modelContext.hasChanges else { return }
        try modelContext.save()
    }

    func rollback() {
        modelContext.rollback()
    }

    private func findHabit(id: UUID) throws -> Habit? {
        try fetchHabits().first { $0.id == id }
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

enum HabitSnapshotMapper {
    static func makeSnapshot(from habit: Habit) -> HabitSnapshot {
        HabitSnapshot(
            id: habit.id,
            name: habit.name,
            habitDescription: habit.habitDescription,
            icon: habit.icon,
            colorHex: habit.colorHex,
            createdAt: habit.createdAt,
            archivedAt: habit.archivedAt,
            sortOrder: habit.sortOrder,
            seriesID: habit.seriesID,
            replacedHabitID: habit.replacedHabitID,
            versionNumber: habit.versionNumber,
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
