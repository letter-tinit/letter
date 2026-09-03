import Foundation
import Utility

public protocol HabitListUseCase {
    func habits(
        from habits: [HabitSnapshot],
        scheduledOn date: Date,
        relativeTo today: Date,
        calendar: Calendar
    ) -> [HabitListItem]
    func dayProgress(
        for dates: [Date],
        habits: [HabitSnapshot],
        calendar: Calendar
    ) -> [HabitDayProgress]
}

/// Read-only business rules for presenting habits on the home screen.
///
/// This policy only accepts immutable domain values. Persistence records are
/// mapped before reaching this boundary.
public struct ImpHabitListUseCase: HabitListUseCase {
    private let schedule = ImpHabitScheduleUseCase()

    public func habits(
        from habits: [HabitSnapshot],
        scheduledOn date: Date,
        relativeTo today: Date,
        calendar: Calendar
    ) -> [HabitListItem] {
        let targetDate = calendar.startOfDay(for: date)

        return habits
            .filter { schedule.isScheduled($0, on: targetDate, calendar: calendar) }
            .sorted { first, second in
                let firstIsClosed = isClosed(first, on: targetDate, calendar: calendar)
                let secondIsClosed = isClosed(second, on: targetDate, calendar: calendar)

                if firstIsClosed != secondIsClosed {
                    return !firstIsClosed
                }

                return first.sortOrder < second.sortOrder
            }
            .map {
                makeListItem(
                    from: $0,
                    on: targetDate,
                    relativeTo: today,
                    calendar: calendar
                )
            }
    }

    public func dayProgress(
        for dates: [Date],
        habits: [HabitSnapshot],
        calendar: Calendar
    ) -> [HabitDayProgress] {
        let targetDates = Set(dates.map { calendar.startOfDay(for: $0) })
        let entriesByHabitID = entriesByHabitID(
            habits: habits,
            targetDates: targetDates,
            calendar: calendar
        )

        return dates.map { date in
            let targetDate = calendar.startOfDay(for: date)
            let scheduledHabits = habits.filter {
                schedule.isScheduled($0, on: targetDate, calendar: calendar)
            }

            guard !scheduledHabits.isEmpty else {
                return HabitDayProgress(
                    date: date,
                    isComplete: false,
                    completionRatio: 0
                )
            }

            var activeHabitCount = 0
            let totalRatio = scheduledHabits.reduce(0.0) { result, habit in
                guard habit.goalCount > 0 else {
                    return result
                }

                let entry = entriesByHabitID[habit.id]?[targetDate]
                guard entry?.isSkipped != true else {
                    return result
                }

                activeHabitCount += 1
                let completedCount = entry?.completedCount ?? 0
                let ratio = min(Double(completedCount) / Double(habit.goalCount), 1)
                return result + ratio
            }
            let completionRatio = activeHabitCount == 0
                ? 1
                : totalRatio / Double(activeHabitCount)

            return HabitDayProgress(
                date: date,
                isComplete: completionRatio == 1,
                completionRatio: completionRatio
            )
        }
    }
}

extension ImpHabitListUseCase {
    public func makeListItem(
        from habit: HabitSnapshot,
        on date: Date,
        relativeTo today: Date,
        calendar: Calendar
    ) -> HabitListItem {
        let entry = habit.entries.first { calendar.isDate($0.date, inSameDayAs: date) }
        let isCompleted = entry?.isCompleted(goalCount: habit.goalCount) ?? false
        let isSkipped = entry?.isSkipped ?? false
        let canEditEntry = date <= calendar.startOfDay(for: today)

        return HabitListItem(
            id: habit.id,
            name: habit.name,
            icon: habit.icon,
            colorHex: habit.colorHex,
            goalType: habit.goalType,
            goalCount: habit.goalCount,
            goalUnit: habit.goalUnit,
            completedCount: entry?.completedCount ?? 0,
            completionRatio: entry?.completionRatio(goalCount: habit.goalCount) ?? 0,
            isSkipped: isSkipped,
            currentStreak: habit.currentStreak,
            longestStreak: habit.longestStreak,
            lastCompletedDate: habit.lastCompletedDate,
            canEditEntry: canEditEntry,
            canResetEntry: canEditEntry || isSkipped,
            entryIsCompleted: isCompleted
        )
    }

    public func isClosed(_ habit: HabitSnapshot, on date: Date, calendar: Calendar) -> Bool {
        let entry = habit.entries.first {
            calendar.isDate($0.date, inSameDayAs: date)
        }

        return entry?.isSkipped == true ||
            (entry?.isCompleted(goalCount: habit.goalCount) == true)
    }

    public func entriesByHabitID(
        habits: [HabitSnapshot],
        targetDates: Set<Date>,
        calendar: Calendar
    ) -> [UUID: [Date: HabitEntrySnapshot]] {
        habits.reduce(into: [:]) { result, habit in
            for entry in habit.entries {
                let entryDate = calendar.startOfDay(for: entry.date)
                guard targetDates.contains(entryDate) else {
                    continue
                }

                result[habit.id, default: [:]][entryDate] = entry
            }
        }
    }
}
