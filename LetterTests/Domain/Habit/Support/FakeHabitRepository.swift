import Foundation
@testable import Domain

@MainActor
final class FakeHabitRepository: HabitRepository {
    var habits: [HabitSnapshot]
    var usesCompactStatisticsView = false
    var createdHabitInputs: [(draft: HabitDraft, id: UUID, createdAt: Date, sortOrder: Int)] = []
    var updatedHabitInputs: [(id: UUID, draft: HabitDraft, streak: HabitStreakValues)] = []
    var createdVersionInputs: [(sourceID: UUID, draft: HabitDraft, id: UUID, startDate: Date, sourceEndDate: Date, versionNumber: Int, streak: HabitStreakValues)] = []
    var archivedInputs: [(archived: Bool, id: UUID, date: Date)] = []
    var deletedHabitInputs: [(id: UUID, replacementID: UUID?)] = []
    var deletedHabitIDSets: [Set<UUID>] = []
    var persistedEntries: [(values: HabitEntryValues, habitID: UUID, streak: HabitStreakValues)] = []

    init(habits: [HabitSnapshot] = []) {
        self.habits = habits
    }

    func fetchHabitSnapshots() throws -> [HabitSnapshot] {
        habits
    }

    func fetchUserProfile() throws -> UserProfileSnapshot? { nil }

    func createDefaultUserProfile() throws -> UserProfileSnapshot {
        UserProfileSnapshot(
            id: UUID(),
            displayName: "Tester",
            avatarOriginalData: nil,
            avatarData: nil,
            weekStartsOnMonday: true,
            colorScheme: .light
        )
    }

    func updateProfileWeekStart(_ enabled: Bool) throws -> UserProfileSnapshot? { nil }
    func updateProfileColorScheme(_ colorScheme: AppColorScheme) throws -> UserProfileSnapshot? { nil }
    func updateProfile(displayName: String, avatarOriginalData: Data?, avatarData: Data?) throws -> UserProfileSnapshot? { nil }

    func fetchUsesCompactStatisticsView() throws -> Bool {
        usesCompactStatisticsView
    }

    func setUsesCompactStatisticsView(_ enabled: Bool) throws {
        usesCompactStatisticsView = enabled
    }

    func createHabit(from draft: HabitDraft, id: UUID, createdAt: Date, sortOrder: Int) throws -> HabitSnapshot {
        createdHabitInputs.append((draft, id, createdAt, sortOrder))
        let habit = HabitTestSupport.makeHabit(
            id: id,
            name: draft.name,
            createdAt: createdAt,
            sortOrder: sortOrder,
            startDate: draft.startDate,
            endDate: draft.endDate,
            frequency: draft.frequency,
            targetDaysOfWeek: draft.targetDaysOfWeek,
            goalCount: draft.goalCount
        )
        habits.append(habit)
        return habit
    }

    func updateHabit(id: UUID, from draft: HabitDraft, streak: HabitStreakValues) throws -> HabitSnapshot? {
        updatedHabitInputs.append((id, draft, streak))
        guard let index = habits.firstIndex(where: { $0.id == id }) else { return nil }
        let updated = HabitTestSupport.makeHabit(
            id: id,
            name: draft.name,
            createdAt: habits[index].createdAt,
            archivedAt: habits[index].archivedAt,
            sortOrder: habits[index].sortOrder,
            startDate: draft.startDate,
            endDate: draft.endDate,
            frequency: draft.frequency,
            targetDaysOfWeek: draft.targetDaysOfWeek,
            goalCount: draft.goalCount,
            currentStreak: streak.current,
            longestStreak: streak.longest,
            lastCompletedDate: streak.lastCompletedDate,
            entries: habits[index].entries
        )
        habits[index] = updated
        return updated
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
        createdVersionInputs.append((sourceID, draft, id, startDate, sourceEndDate, versionNumber, streak))
        guard let sourceIndex = habits.firstIndex(where: { $0.id == sourceID }) else { return nil }
        let source = habits[sourceIndex]
        habits[sourceIndex] = HabitTestSupport.makeHabit(
            id: source.id,
            createdAt: source.createdAt,
            sortOrder: source.sortOrder,
            seriesID: source.seriesID,
            replacedHabitID: source.replacedHabitID,
            versionNumber: source.versionNumber,
            startDate: source.startDate,
            endDate: sourceEndDate,
            frequency: source.frequency,
            targetDaysOfWeek: source.targetDaysOfWeek,
            goalCount: source.goalCount,
            entries: source.entries
        )
        let version = HabitTestSupport.makeHabit(
            id: id,
            name: draft.name,
            createdAt: createdAt,
            sortOrder: source.sortOrder + 1,
            seriesID: source.effectiveSeriesID,
            replacedHabitID: sourceID,
            versionNumber: versionNumber,
            startDate: startDate,
            endDate: draft.endDate,
            frequency: draft.frequency,
            targetDaysOfWeek: draft.targetDaysOfWeek,
            goalCount: draft.goalCount
        )
        habits.append(version)
        return version
    }

    func setHabitArchived(_ archived: Bool, id: UUID, at date: Date) throws -> HabitSnapshot? {
        archivedInputs.append((archived, id, date))
        guard let index = habits.firstIndex(where: { $0.id == id }) else { return nil }
        let source = habits[index]
        let updated = HabitTestSupport.makeHabit(
            id: source.id,
            name: source.name,
            createdAt: source.createdAt,
            archivedAt: archived ? date : nil,
            sortOrder: source.sortOrder,
            seriesID: source.seriesID,
            replacedHabitID: source.replacedHabitID,
            versionNumber: source.versionNumber,
            startDate: source.startDate,
            endDate: source.endDate,
            frequency: source.frequency,
            targetDaysOfWeek: source.targetDaysOfWeek,
            goalCount: source.goalCount,
            entries: source.entries
        )
        habits[index] = updated
        return updated
    }

    func deleteHabit(id: UUID, reconnectingTo replacementID: UUID?) throws -> Bool {
        deletedHabitInputs.append((id, replacementID))
        let originalCount = habits.count
        habits.removeAll { $0.id == id }
        return habits.count != originalCount
    }

    func deleteHabits(ids: Set<UUID>) throws {
        deletedHabitIDSets.append(ids)
        habits.removeAll { ids.contains($0.id) }
    }

    func persistEntry(_ values: HabitEntryValues, habitID: UUID, streak: HabitStreakValues) throws -> HabitSnapshot? {
        persistedEntries.append((values, habitID, streak))
        guard let index = habits.firstIndex(where: { $0.id == habitID }) else { return nil }
        let source = habits[index]
        let entries = source.entries.filter {
            !HabitTestSupport.calendar.isDate($0.date, inSameDayAs: values.date)
        } + [
            HabitEntrySnapshot(
                date: values.date,
                completedCount: values.completedCount,
                status: values.status
            )
        ]
        let updated = HabitTestSupport.makeHabit(
            id: source.id,
            name: source.name,
            createdAt: source.createdAt,
            archivedAt: source.archivedAt,
            sortOrder: source.sortOrder,
            seriesID: source.seriesID,
            replacedHabitID: source.replacedHabitID,
            versionNumber: source.versionNumber,
            startDate: source.startDate,
            endDate: source.endDate,
            frequency: source.frequency,
            targetDaysOfWeek: source.targetDaysOfWeek,
            goalCount: source.goalCount,
            currentStreak: streak.current,
            longestStreak: streak.longest,
            lastCompletedDate: streak.lastCompletedDate,
            entries: entries
        )
        habits[index] = updated
        return updated
    }
}
