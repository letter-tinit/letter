import Foundation

struct HabitDetailData {
    let habit: HabitSnapshot
    let previousVersionNumber: Int?
    let nextVersionNumber: Int?
    let seriesHabitCount: Int
}

enum HabitDetailError: Error {
    case habitNotFound
    case persistenceFailed(Error)
}

@MainActor
protocol HabitDetailHandling {
    func load(habitID: UUID) throws -> HabitDetailData?
    func setArchived(_ archived: Bool, habitID: UUID, now: Date) throws
    func delete(habitID: UUID) throws
    func deleteSeries(containing habitID: UUID) throws
}

@MainActor
final class HabitDetailUseCase: HabitDetailHandling {
    private let repository: any HabitRepository
    private let snapshots: any HabitSnapshotReading
    private let notifications: any HabitNotificationScheduling

    init(
        repository: any HabitRepository,
        snapshots: any HabitSnapshotReading,
        notifications: any HabitNotificationScheduling
    ) {
        self.repository = repository
        self.snapshots = snapshots
        self.notifications = notifications
    }

    func load(habitID: UUID) throws -> HabitDetailData? {
        let habits = try snapshots.fetchHabitSnapshots()
        guard let habit = habits.first(where: { $0.id == habitID }) else {
            return nil
        }

        let previousVersion = habit.replacedHabitID.flatMap { previousID in
            habits.first { $0.id == previousID }
        }
        let nextVersion = habits
            .filter { $0.replacedHabitID == habit.id }
            .sorted { $0.displayVersionNumber < $1.displayVersionNumber }
            .first
        let seriesCount = habits.filter {
            $0.effectiveSeriesID == habit.effectiveSeriesID
        }.count

        return HabitDetailData(
            habit: habit,
            previousVersionNumber: previousVersion?.displayVersionNumber,
            nextVersionNumber: nextVersion?.displayVersionNumber,
            seriesHabitCount: seriesCount
        )
    }

    func setArchived(_ archived: Bool, habitID: UUID, now: Date) throws {
        guard let habit = try findHabit(id: habitID) else {
            throw HabitDetailError.habitNotFound
        }

        if archived {
            guard habit.archivedAt == nil else { return }
            habit.archivedAt = now
            notifications.cancelNotifications(for: habit)
        } else {
            guard habit.archivedAt != nil else { return }
            habit.archivedAt = nil
        }

        do {
            try repository.save()
            if !archived {
                notifications.rescheduleNotifications(for: habit)
            }
        } catch {
            repository.rollback()
            if archived {
                notifications.rescheduleNotifications(for: habit)
            } else {
                notifications.cancelNotifications(for: habit)
            }
            throw HabitDetailError.persistenceFailed(error)
        }
    }

    func delete(habitID: UUID) throws {
        let habits = try repository.fetchHabits()
        guard let habit = habits.first(where: { $0.id == habitID }) else {
            throw HabitDetailError.habitNotFound
        }

        let replacementID = habit.replacedHabitID
        habits
            .filter { $0.replacedHabitID == habitID }
            .forEach { $0.replacedHabitID = replacementID }
        notifications.cancelNotifications(for: habit)
        repository.removeHabit(habit)
        try commit(restoringNotificationsFor: habit.isArchived ? [] : [habit])
    }

    func deleteSeries(containing habitID: UUID) throws {
        let habits = try repository.fetchHabits()
        guard let habit = habits.first(where: { $0.id == habitID }) else {
            throw HabitDetailError.habitNotFound
        }

        let series = habits.filter {
            $0.effectiveSeriesID == habit.effectiveSeriesID
        }
        for item in series {
            notifications.cancelNotifications(for: item)
            repository.removeHabit(item)
        }
        try commit(restoringNotificationsFor: series.filter { !$0.isArchived })
    }
}

private extension HabitDetailUseCase {
    func findHabit(id: UUID) throws -> Habit? {
        try repository.fetchHabits().first { $0.id == id }
    }

    func commit(restoringNotificationsFor habits: [Habit]) throws {
        do {
            try repository.save()
        } catch {
            repository.rollback()
            habits.forEach(notifications.rescheduleNotifications)
            throw HabitDetailError.persistenceFailed(error)
        }
    }
}
