import Foundation

enum HabitEntryChange {
    case unchanged
    case rejected
    case updated
}

@MainActor
protocol HabitHomeUseCase {
    func fetchHabits() throws -> [Habit]
    func habitItems(
        on date: Date,
        relativeTo today: Date,
        calendar: Calendar
    ) throws -> [HabitListItem]
    func dayProgress(for dates: [Date], calendar: Calendar) throws -> [HabitDayProgress]
    func updateEntry(
        for habit: Habit,
        on date: Date,
        completedCount: Int,
        note: String?,
        calendar: Calendar,
        now: Date
    ) throws -> HabitEntryChange
    func skipEntry(
        for habit: Habit,
        on date: Date,
        calendar: Calendar,
        now: Date
    ) throws -> HabitEntryChange
    func resetEntry(
        for habit: Habit,
        on date: Date,
        calendar: Calendar,
        now: Date
    ) throws -> HabitEntryChange
    func rescheduleNotifications(for habits: [Habit])
}

@MainActor
final class ImpHabitHomeUseCase: HabitHomeUseCase {
    private let repository: any HabitRepository
    private let notifications: any HabitNotificationRepository
    private let listUseCase: ImpHabitListUseCase
    private let entryUseCase: ImpHabitEntryUseCase
    private let streakUseCase: ImpHabitStreakUseCase

    init(
        repository: any HabitRepository,
        notifications: any HabitNotificationRepository
    ) {
        self.repository = repository
        self.notifications = notifications
        listUseCase = ImpHabitListUseCase()
        entryUseCase = ImpHabitEntryUseCase()
        streakUseCase = ImpHabitStreakUseCase()
    }

    func fetchHabits() throws -> [Habit] {
        try repository.fetchHabits()
    }

    func habitItems(
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

    func dayProgress(for dates: [Date], calendar: Calendar) throws -> [HabitDayProgress] {
        listUseCase.dayProgress(
            for: dates,
            habits: try repository.fetchHabitSnapshots(),
            calendar: calendar
        )
    }

    func updateEntry(
        for habit: Habit,
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

    func skipEntry(
        for habit: Habit,
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

    func resetEntry(
        for habit: Habit,
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

    func rescheduleNotifications(for habits: [Habit]) {
        habits.forEach(notifications.rescheduleNotifications)
    }
}

private extension ImpHabitHomeUseCase {
    func persist(
        _ mutation: HabitEntryMutation,
        for habit: Habit,
        calendar: Calendar
    ) throws -> HabitEntryChange {
        switch mutation {
        case .unchanged:
            return .unchanged
        case .rejected:
            return .rejected
        case .updated:
            break
        case .inserted(let entry):
            repository.addEntry(entry)
        }

        let streak = streakUseCase.calculate(for: habit, calendar: calendar)
        habit.currentStreak = streak.currentStreak
        habit.longestStreak = streak.longestStreak
        habit.lastCompletedDate = streak.lastCompletedDate

        do {
            try repository.save()
            return .updated
        } catch {
            repository.rollback()
            throw error
        }
    }
}
