import Foundation

struct HabitStreakResult {
    let currentStreak: Int
    let longestStreak: Int
    let lastCompletedDate: Date?
}

protocol HabitStreakUseCase {
    func calculate(for habit: Habit, calendar: Calendar) -> HabitStreakResult
    func calculate<Schedule: HabitScheduling>(
        schedule: Schedule,
        entries: [HabitEntrySnapshot],
        goalCount: Int,
        calendar: Calendar
    ) -> HabitStreakResult
}

struct ImpHabitStreakUseCase: HabitStreakUseCase {
    private let habitSchedule = ImpHabitScheduleUseCase()

    func calculate(for habit: Habit, calendar: Calendar) -> HabitStreakResult {
        calculate(
            schedule: habit,
            completedDates: habit.entries.filter(\.isCompleted).map(\.date),
            skippedDates: habit.entries.filter(\.isSkipped).map(\.date),
            calendar: calendar
        )
    }

    func calculate(
        schedule: some HabitScheduling,
        entries: [HabitEntrySnapshot],
        goalCount: Int,
        calendar: Calendar
    ) -> HabitStreakResult {
        calculate(
            schedule: schedule,
            completedDates: entries.filter { $0.isCompleted(goalCount: goalCount) }.map(\.date),
            skippedDates: entries.filter(\.isSkipped).map(\.date),
            calendar: calendar
        )
    }
}

private extension ImpHabitStreakUseCase {
    func calculate(
        schedule: some HabitScheduling,
        completedDates rawCompletedDates: [Date],
        skippedDates rawSkippedDates: [Date],
        calendar: Calendar
    ) -> HabitStreakResult {
        let completedDates = Set(rawCompletedDates
            .map { calendar.startOfDay(for: $0) }
            .filter { habitSchedule.isScheduled(schedule, on: $0, calendar: calendar) })
        let skippedDates = Set(rawSkippedDates
            .map { calendar.startOfDay(for: $0) }
            .filter { habitSchedule.isScheduled(schedule, on: $0, calendar: calendar) })

        guard let lastCompletedDate = completedDates.max() else {
            return HabitStreakResult(currentStreak: 0, longestStreak: 0, lastCompletedDate: nil)
        }

        return HabitStreakResult(
            currentStreak: streakEnding(
                at: lastCompletedDate,
                completedDates: completedDates,
                skippedDates: skippedDates,
                schedule: schedule,
                calendar: calendar
            ),
            longestStreak: longestStreak(
                completedDates: completedDates,
                skippedDates: skippedDates,
                schedule: schedule,
                calendar: calendar
            ),
            lastCompletedDate: lastCompletedDate
        )
    }

    func longestStreak(
        completedDates: Set<Date>,
        skippedDates: Set<Date>,
        schedule: some HabitScheduling,
        calendar: Calendar
    ) -> Int {
        var longestStreak = 0

        for date in completedDates.sorted() {
            longestStreak = max(
                longestStreak,
                streakEnding(
                    at: date,
                    completedDates: completedDates,
                    skippedDates: skippedDates,
                    schedule: schedule,
                    calendar: calendar
                )
            )
        }

        return longestStreak
    }

    func streakEnding(
        at date: Date,
        completedDates: Set<Date>,
        skippedDates: Set<Date>,
        schedule: some HabitScheduling,
        calendar: Calendar
    ) -> Int {
        var streak = 0
        var checkDate = calendar.startOfDay(for: date)

        while completedDates.contains(checkDate) || skippedDates.contains(checkDate) {
            if completedDates.contains(checkDate) {
                streak += 1
            }

            guard let previousDate = previousScheduledDate(
                before: checkDate,
                schedule: schedule,
                calendar: calendar
            ) else {
                break
            }
            checkDate = previousDate
        }

        return streak
    }

    func previousScheduledDate(
        before date: Date,
        schedule: some HabitScheduling,
        calendar: Calendar
    ) -> Date? {
        var date = calendar.startOfDay(for: date)
        let startDay = calendar.startOfDay(for: schedule.effectiveStartDate)

        repeat {
            guard let previousDay = calendar.date(byAdding: .day, value: -1, to: date) else {
                return nil
            }
            date = previousDay

            if date < startDay {
                return nil
            }
        } while !habitSchedule.isScheduled(schedule, on: date, calendar: calendar)

        return date
    }
}
