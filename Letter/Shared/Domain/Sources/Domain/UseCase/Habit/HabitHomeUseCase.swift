import Foundation
import Utility

public enum HabitEntryChange {
    case unchanged
    case rejected
    case updated
}

public enum HabitHomeError: Error {
    case habitNotFound
}

@MainActor
public protocol HabitHomeUseCase {
    func fetchHabits() throws -> [HabitSnapshot]
    func habitItems(
        on date: Date,
        relativeTo today: Date,
        calendar: Calendar
    ) throws -> [HabitListItem]
    func dayProgress(for dates: [Date], calendar: Calendar) throws -> [HabitDayProgress]
    func updateEntry(
        for habit: HabitSnapshot,
        on date: Date,
        completedCount: Int,
        note: String?,
        calendar: Calendar,
        now: Date
    ) throws -> HabitEntryChange
    func skipEntry(
        for habit: HabitSnapshot,
        on date: Date,
        calendar: Calendar,
        now: Date
    ) throws -> HabitEntryChange
    func resetEntry(
        for habit: HabitSnapshot,
        on date: Date,
        calendar: Calendar,
        now: Date
    ) throws -> HabitEntryChange
    func rescheduleNotifications(for habits: [HabitSnapshot])
}

@MainActor
public final class ImpHabitHomeUseCase: HabitHomeUseCase {
    private let repository: any HabitRepository
    private let notifications: any HabitNotificationRepository
    private let listUseCase: ImpHabitListUseCase
    private let entryUseCase: ImpHabitEntryUseCase
    private let streakUseCase: ImpHabitStreakUseCase

    public init(
        repository: any HabitRepository,
        notifications: any HabitNotificationRepository
    ) {
        self.repository = repository
        self.notifications = notifications
        listUseCase = ImpHabitListUseCase()
        entryUseCase = ImpHabitEntryUseCase()
        streakUseCase = ImpHabitStreakUseCase()
    }

    public func fetchHabits() throws -> [HabitSnapshot] {
        try repository.fetchHabitSnapshots()
    }

    public func habitItems(
        on date: Date,
        relativeTo today: Date,
        calendar: Calendar
    ) throws -> [HabitListItem] {
        listUseCase.habits(
            from: try repository.fetchHabitSnapshots(),
            scheduledOn: date,
            relativeTo: today,
            calendar: calendar
        )
    }

    public func dayProgress(for dates: [Date], calendar: Calendar) throws -> [HabitDayProgress] {
        listUseCase.dayProgress(
            for: dates,
            habits: try repository.fetchHabitSnapshots(),
            calendar: calendar
        )
    }

    public func updateEntry(
        for habit: HabitSnapshot,
        on date: Date,
        completedCount: Int,
        note: String?,
        calendar: Calendar,
        now: Date
    ) throws -> HabitEntryChange {
        try persist(
            entryUseCase.updateProgress(
                for: habit,
                on: date,
                completedCount: completedCount,
                note: note,
                calendar: calendar,
                now: now
            ),
            for: habit,
            calendar: calendar
        )
    }

    public func skipEntry(
        for habit: HabitSnapshot,
        on date: Date,
        calendar: Calendar,
        now: Date
    ) throws -> HabitEntryChange {
        try persist(
            entryUseCase.skip(habit, on: date, calendar: calendar, now: now),
            for: habit,
            calendar: calendar
        )
    }

    public func resetEntry(
        for habit: HabitSnapshot,
        on date: Date,
        calendar: Calendar,
        now: Date
    ) throws -> HabitEntryChange {
        try persist(
            entryUseCase.reset(habit, on: date, calendar: calendar, now: now),
            for: habit,
            calendar: calendar
        )
    }

    public func rescheduleNotifications(for habits: [HabitSnapshot]) {
        habits.forEach(notifications.rescheduleNotifications)
    }
}

private extension ImpHabitHomeUseCase {
    public func persist(
        _ mutation: HabitEntryMutation,
        for habit: HabitSnapshot,
        calendar: Calendar
    ) throws -> HabitEntryChange {
        switch mutation {
        case .unchanged:
            return .unchanged
        case .rejected:
            return .rejected
        case .upsert(let values):
            var entries = habit.entries.filter {
                !calendar.isDate($0.date, inSameDayAs: values.date)
            }
            entries.append(HabitEntrySnapshot(
                date: values.date,
                completedCount: values.completedCount,
                status: values.status
            ))

            let streak = streakUseCase.calculate(
                schedule: habit,
                entries: entries,
                goalCount: habit.goalCount,
                calendar: calendar
            )
            guard try repository.persistEntry(
                values,
                habitID: habit.id,
                streak: HabitStreakValues(
                    current: streak.currentStreak,
                    longest: streak.longestStreak,
                    lastCompletedDate: streak.lastCompletedDate
                )
            ) != nil else {
                throw HabitHomeError.habitNotFound
            }
            return .updated
        }
    }
}
