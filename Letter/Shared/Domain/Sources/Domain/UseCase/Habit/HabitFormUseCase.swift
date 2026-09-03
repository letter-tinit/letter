import Foundation
import Utility

@MainActor
public protocol HabitFormUseCase {
    func loadHabit(id: UUID) throws -> HabitSnapshot?
    func save(
        mode: HabitFormMode,
        draft: HabitDraft,
        calendar: Calendar,
        now: Date
    ) throws -> UUID
}

@MainActor
public final class ImpHabitFormUseCase: HabitFormUseCase {
    private let repository: any HabitRepository
    private let notifications: any HabitNotificationRepository
    private let streakUseCase = ImpHabitStreakUseCase()
    private let versionUseCase = ImpHabitVersionUseCase()

    public init(
        repository: any HabitRepository,
        notifications: any HabitNotificationRepository
    ) {
        self.repository = repository
        self.notifications = notifications
    }

    public func loadHabit(id: UUID) throws -> HabitSnapshot? {
        try repository.fetchHabitSnapshots().first { $0.id == id }
    }

    public func save(
        mode: HabitFormMode,
        draft: HabitDraft,
        calendar: Calendar,
        now: Date
    ) throws -> UUID {
        switch mode {
        case .create:
            try createHabit(from: draft, now: now)
        case .edit(let id):
            try updateHabit(id: id, from: draft, calendar: calendar)
        case .newVersion(let sourceID):
            try createVersion(
                replacing: sourceID,
                from: draft,
                calendar: calendar,
                now: now
            )
        }
    }
}

extension ImpHabitFormUseCase {
    public func createHabit(from draft: HabitDraft, now: Date) throws -> UUID {
        do {
            let habits = try repository.fetchHabitSnapshots()
            let habit = try repository.createHabit(
                from: draft,
                id: UUID(),
                createdAt: now,
                sortOrder: (habits.map(\.sortOrder).max() ?? -1) + 1
            )
            notifications.rescheduleNotifications(for: habit)
            return habit.id
        } catch let error as HabitFormError {
            throw error
        } catch {
            throw HabitFormError.persistenceFailed(error)
        }
    }

    public func updateHabit(
        id: UUID,
        from draft: HabitDraft,
        calendar: Calendar
    ) throws -> UUID {
        guard let source = try loadHabit(id: id) else {
            throw HabitFormError.habitNotFound
        }

        notifications.cancelNotifications(for: source)
        do {
            let streak = calculateStreak(for: source, using: draft, calendar: calendar)
            guard let habit = try repository.updateHabit(id: id, from: draft, streak: streak) else {
                notifications.rescheduleNotifications(for: source)
                throw HabitFormError.habitNotFound
            }
            notifications.rescheduleNotifications(for: habit)
            return habit.id
        } catch let error as HabitFormError {
            throw error
        } catch {
            notifications.rescheduleNotifications(for: source)
            throw HabitFormError.persistenceFailed(error)
        }
    }

    public func createVersion(
        replacing sourceID: UUID,
        from draft: HabitDraft,
        calendar: Calendar,
        now: Date
    ) throws -> UUID {
        let habits = try repository.fetchHabitSnapshots()
        guard let source = habits.first(where: { $0.id == sourceID }) else {
            throw HabitFormError.habitNotFound
        }

        let plan = versionUseCase.plan(
            replacing: source,
            in: habits,
            proposedStartDate: draft.startDate,
            now: now,
            calendar: calendar
        )
        let streak = calculateStreak(
            for: source,
            endingAt: plan.sourceEndDate,
            calendar: calendar
        )

        notifications.cancelNotifications(for: source)
        do {
            guard let habit = try repository.createHabitVersion(
                replacing: sourceID,
                from: draft,
                id: UUID(),
                createdAt: now,
                startDate: plan.newStartDate,
                sourceEndDate: plan.sourceEndDate,
                versionNumber: plan.versionNumber,
                streak: streak
            ) else {
                notifications.rescheduleNotifications(for: source)
                throw HabitFormError.habitNotFound
            }
            notifications.rescheduleNotifications(for: habit)
            return habit.id
        } catch let error as HabitFormError {
            throw error
        } catch {
            notifications.rescheduleNotifications(for: source)
            throw HabitFormError.persistenceFailed(error)
        }
    }

    public func calculateStreak(
        for habit: HabitSnapshot,
        using draft: HabitDraft,
        calendar: Calendar
    ) -> HabitStreakValues {
        let schedule = HabitScheduleConfiguration(
            effectiveStartDate: draft.startDate,
            endDate: draft.endDate,
            archivedAt: habit.archivedAt,
            frequency: habit.frequency,
            targetDaysOfWeek: habit.targetDaysOfWeek
        )
        return streakValues(
            for: schedule,
            entries: habit.entries,
            goalCount: habit.goalCount,
            calendar: calendar
        )
    }

    public func calculateStreak(
        for habit: HabitSnapshot,
        endingAt endDate: Date,
        calendar: Calendar
    ) -> HabitStreakValues {
        let schedule = HabitScheduleConfiguration(
            effectiveStartDate: habit.effectiveStartDate,
            endDate: endDate,
            archivedAt: habit.archivedAt,
            frequency: habit.frequency,
            targetDaysOfWeek: habit.targetDaysOfWeek
        )
        return streakValues(
            for: schedule,
            entries: habit.entries,
            goalCount: habit.goalCount,
            calendar: calendar
        )
    }

    public func streakValues(
        for schedule: HabitScheduleConfiguration,
        entries: [HabitEntrySnapshot],
        goalCount: Int,
        calendar: Calendar
    ) -> HabitStreakValues {
        let result = streakUseCase.calculate(
            schedule: schedule,
            entries: entries,
            goalCount: goalCount,
            calendar: calendar
        )
        return HabitStreakValues(
            current: result.currentStreak,
            longest: result.longestStreak,
            lastCompletedDate: result.lastCompletedDate
        )
    }
}
