import Foundation
import SwiftData

@MainActor
final class SwiftDataHabitRepository: HabitRepository, HabitSnapshotReading {
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
        try fetchHabits().map(Self.makeSnapshot)
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

    private static func makeSnapshot(from habit: Habit) -> HabitSnapshot {
        HabitSnapshot(
            id: habit.id,
            name: habit.name,
            icon: habit.icon,
            colorHex: habit.colorHex,
            createdAt: habit.createdAt,
            archivedAt: habit.archivedAt,
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
