import Foundation

struct HabitStreakResult {
    let currentStreak: Int
    let longestStreak: Int
    let lastCompletedDate: Date?
}

struct HabitStreakCalculator {
    private let habitSchedule = HabitSchedule()

    func calculate(for habit: Habit, calendar: Calendar) -> HabitStreakResult {
        let completedDates = Set(
            habit.entries
                .filter { $0.isCompleted }
                .map { calendar.startOfDay(for: $0.date) }
                .filter { habitSchedule.isScheduled(habit, on: $0, calendar: calendar) }
        )
        let skippedDates = Set(
            habit.entries
                .filter { $0.isSkipped }
                .map { calendar.startOfDay(for: $0.date) }
                .filter { habitSchedule.isScheduled(habit, on: $0, calendar: calendar) }
        )

        guard let lastCompletedDate = completedDates.max() else {
            return HabitStreakResult(currentStreak: 0, longestStreak: 0, lastCompletedDate: nil)
        }

        return HabitStreakResult(
            currentStreak: streakEnding(
                at: lastCompletedDate,
                completedDates: completedDates,
                skippedDates: skippedDates,
                habit: habit,
                calendar: calendar
            ),
            longestStreak: longestStreak(
                completedDates: completedDates,
                skippedDates: skippedDates,
                habit: habit,
                calendar: calendar
            ),
            lastCompletedDate: lastCompletedDate
        )
    }
}

private extension HabitStreakCalculator {
    func longestStreak(
        completedDates: Set<Date>,
        skippedDates: Set<Date>,
        habit: Habit,
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
                    habit: habit,
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
        habit: Habit,
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
                habit: habit,
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
        habit: Habit,
        calendar: Calendar
    ) -> Date? {
        var date = calendar.startOfDay(for: date)
        let startDay = calendar.startOfDay(for: habit.effectiveStartDate)

        repeat {
            guard let previousDay = calendar.date(byAdding: .day, value: -1, to: date) else {
                return nil
            }
            date = previousDay

            if date < startDay {
                return nil
            }
        } while !habitSchedule.isScheduled(habit, on: date, calendar: calendar)

        return date
    }
}
