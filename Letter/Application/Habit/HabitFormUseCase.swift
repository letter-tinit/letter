import Foundation

enum HabitFormMode: Equatable {
    case create
    case edit(UUID)
    case newVersion(UUID)
}

struct HabitDraft {
    let name: String
    let description: String
    let icon: String
    let colorHex: String
    let startDate: Date
    let endDate: Date?
    let frequency: HabitFrequency
    let targetDaysOfWeek: [Int]
    let goalType: GoalType
    let goalCount: Int
    let goalUnit: String
    let reminders: [HabitReminderConfiguration]
}

enum HabitFormError: Error {
    case habitNotFound
    case persistenceFailed(Error)
}

@MainActor
protocol HabitFormHandling {
    func loadHabit(id: UUID) throws -> HabitSnapshot?
    func save(
        mode: HabitFormMode,
        draft: HabitDraft,
        calendar: Calendar,
        now: Date
    ) throws -> UUID
}

@MainActor
final class HabitFormUseCase: HabitFormHandling {
    private let repository: any HabitRepository
    private let snapshots: any HabitSnapshotReading
    private let notifications: any HabitNotificationScheduling
    private let streakCalculator = HabitStreakCalculator()

    init(
        repository: any HabitRepository,
        snapshots: any HabitSnapshotReading,
        notifications: any HabitNotificationScheduling
    ) {
        self.repository = repository
        self.snapshots = snapshots
        self.notifications = notifications
    }

    func loadHabit(id: UUID) throws -> HabitSnapshot? {
        try snapshots.fetchHabitSnapshots().first { $0.id == id }
    }

    func save(
        mode: HabitFormMode,
        draft: HabitDraft,
        calendar: Calendar,
        now: Date
    ) throws -> UUID {
        switch mode {
        case .create:
            return try createHabit(from: draft)
        case .edit(let id):
            return try updateHabit(id: id, from: draft, calendar: calendar)
        case .newVersion(let sourceID):
            return try createVersion(
                replacing: sourceID,
                from: draft,
                calendar: calendar,
                now: now
            )
        }
    }
}

private extension HabitFormUseCase {
    func createHabit(from draft: HabitDraft) throws -> UUID {
        let habit = makeHabit(from: draft)
        let habits = try repository.fetchHabits()
        habit.sortOrder = (habits.map(\.sortOrder).max() ?? -1) + 1
        replaceReminders(for: habit, with: draft.reminders)
        repository.addHabit(habit)

        try commit(orReschedule: nil)
        notifications.rescheduleNotifications(for: habit)
        return habit.id
    }

    func updateHabit(
        id: UUID,
        from draft: HabitDraft,
        calendar: Calendar
    ) throws -> UUID {
        guard let habit = try findHabit(id: id) else {
            throw HabitFormError.habitNotFound
        }

        notifications.cancelNotifications(for: habit)
        habit.name = draft.name
        habit.habitDescription = draft.description
        habit.icon = draft.icon
        habit.colorHex = draft.colorHex
        habit.startDate = draft.startDate
        habit.endDate = draft.endDate
        replaceReminders(for: habit, with: draft.reminders)
        updateStreaks(for: habit, calendar: calendar)

        try commit(orReschedule: habit)
        notifications.rescheduleNotifications(for: habit)
        return habit.id
    }

    func createVersion(
        replacing sourceID: UUID,
        from draft: HabitDraft,
        calendar: Calendar,
        now: Date
    ) throws -> UUID {
        guard let oldHabit = try findHabit(id: sourceID) else {
            throw HabitFormError.habitNotFound
        }

        let habits = try repository.fetchHabits()
        let today = calendar.startOfDay(for: now)
        let minimumStart = calendar.date(byAdding: .day, value: 1, to: today) ?? today
        let newStart = max(calendar.startOfDay(for: draft.startDate), minimumStart)
        let oldStart = calendar.startOfDay(for: oldHabit.effectiveStartDate)
        let proposedOldEnd = calendar.date(byAdding: .day, value: -1, to: newStart) ?? today
        let oldEnd = max(proposedOldEnd, oldStart)
        let versionNumber = nextVersionNumber(after: oldHabit, in: habits)
        let newHabit = makeHabit(from: draft)

        notifications.cancelNotifications(for: oldHabit)
        oldHabit.endDate = oldHabit.endDate.map {
            min(max(calendar.startOfDay(for: $0), oldStart), oldEnd)
        } ?? oldEnd
        oldHabit.archivedAt = now

        newHabit.startDate = newStart
        newHabit.seriesID = oldHabit.effectiveSeriesID
        newHabit.replacedHabitID = oldHabit.id
        newHabit.versionNumber = versionNumber
        newHabit.sortOrder = oldHabit.sortOrder
        replaceReminders(for: newHabit, with: draft.reminders)
        updateStreaks(for: oldHabit, calendar: calendar)
        repository.addHabit(newHabit)

        try commit(orReschedule: oldHabit)
        notifications.rescheduleNotifications(for: newHabit)
        return newHabit.id
    }

    func makeHabit(from draft: HabitDraft) -> Habit {
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

    func findHabit(id: UUID) throws -> Habit? {
        try repository.fetchHabits().first { $0.id == id }
    }

    func nextVersionNumber(after habit: Habit, in habits: [Habit]) -> Int {
        let highestVersion = habits
            .filter { $0.effectiveSeriesID == habit.effectiveSeriesID }
            .map(\.displayVersionNumber)
            .max() ?? habit.displayVersionNumber
        return highestVersion + 1
    }

    func updateStreaks(for habit: Habit, calendar: Calendar) {
        let result = streakCalculator.calculate(for: habit, calendar: calendar)
        habit.currentStreak = result.currentStreak
        habit.longestStreak = result.longestStreak
        habit.lastCompletedDate = result.lastCompletedDate
    }

    func replaceReminders(
        for habit: Habit,
        with configurations: [HabitReminderConfiguration]
    ) {
        habit.reminders.forEach(repository.removeReminder)
        habit.reminders.removeAll()

        for configuration in configurations.sorted(by: { $0.time < $1.time }) {
            let reminder = HabitReminder(
                time: configuration.time,
                daysOfWeek: configuration.daysOfWeek,
                isEnabled: configuration.isEnabled
            )
            reminder.id = configuration.id
            reminder.habit = habit
            habit.reminders.append(reminder)
            repository.addReminder(reminder)
        }
    }

    func commit(orReschedule habit: Habit?) throws {
        do {
            try repository.save()
        } catch {
            repository.rollback()
            if let habit {
                notifications.rescheduleNotifications(for: habit)
            }
            throw HabitFormError.persistenceFailed(error)
        }
    }
}
