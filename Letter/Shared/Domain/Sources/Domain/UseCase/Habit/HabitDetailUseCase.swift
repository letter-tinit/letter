import Foundation
import Utility

@MainActor
public protocol HabitDetailUseCase {
    func load(habitID: UUID) throws -> HabitDetailData?
    func complete(habitID: UUID, completedAt: Date, calendar: Calendar) throws
    func delete(habitID: UUID) throws
}

@MainActor
public final class ImpHabitDetailUseCase: HabitDetailUseCase {
    private let repository: any HabitRepository
    private let notifications: any HabitNotificationRepository
    private let streakUseCase = ImpHabitStreakUseCase()

    public init(
        repository: any HabitRepository,
        notifications: any HabitNotificationRepository
    ) {
        self.repository = repository
        self.notifications = notifications
    }

    public func load(habitID: UUID) throws -> HabitDetailData? {
        let habits = try repository.fetchHabitSnapshots()
        guard let habit = habits.first(where: { $0.id == habitID }) else {
            return nil
        }

        return HabitDetailData(habit: habit)
    }

    public func complete(habitID: UUID, completedAt: Date, calendar: Calendar) throws {
        let habits = try repository.fetchHabitSnapshots()
        guard let habit = habits.first(where: { $0.id == habitID }) else {
            throw HabitDetailError.habitNotFound
        }

        notifications.cancelNotifications(for: habit)
        do {
            let completedDay = calendar.startOfDay(for: completedAt)
            var entries = habit.entries.filter {
                !calendar.isDate($0.date, inSameDayAs: completedDay)
            }
            entries.append(HabitEntrySnapshot(
                date: completedDay,
                completedCount: habit.goalCount,
                status: .active
            ))
            let streak = streakUseCase.calculate(
                schedule: habit,
                entries: entries,
                goalCount: habit.goalCount,
                calendar: calendar
            )
            let values = HabitEntryValues(
                date: completedDay,
                completedCount: habit.goalCount,
                status: .active,
                note: nil,
                updatedAt: completedAt
            )
            guard try repository.persistEntry(
                values,
                habitID: habitID,
                streak: HabitStreakValues(
                    current: streak.currentStreak,
                    longest: streak.longestStreak,
                    lastCompletedDate: streak.lastCompletedDate
                )
            ) != nil,
                  try repository.completeHabit(id: habitID, completedAt: completedAt) != nil else {
                restoreNotification(for: habit)
                throw HabitDetailError.habitNotFound
            }
        } catch let error as HabitDetailError {
            throw error
        } catch {
            restoreNotification(for: habit)
            throw HabitDetailError.persistenceFailed(error)
        }
    }

    public func delete(habitID: UUID) throws {
        let habits = try repository.fetchHabitSnapshots()
        guard let habit = habits.first(where: { $0.id == habitID }) else {
            throw HabitDetailError.habitNotFound
        }

        notifications.cancelNotifications(for: habit)
        do {
            guard try repository.deleteHabit(id: habitID) else {
                restoreNotification(for: habit)
                throw HabitDetailError.habitNotFound
            }
        } catch let error as HabitDetailError {
            throw error
        } catch {
            restoreNotification(for: habit)
            throw HabitDetailError.persistenceFailed(error)
        }
    }

}

extension ImpHabitDetailUseCase {
    public func snapshot(id: UUID) throws -> HabitSnapshot? {
        try repository.fetchHabitSnapshots().first { $0.id == id }
    }

    public func restoreNotification(for habit: HabitSnapshot) {
        notifications.rescheduleNotifications(for: habit)
    }
}
