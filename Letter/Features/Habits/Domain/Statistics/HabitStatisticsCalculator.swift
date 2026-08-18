import Foundation

struct HabitStatisticsCalculator {
    private let habitSchedule = HabitSchedule()

    func completionRatio(habits: [Habit], on date: Date, calendar: Calendar) -> Double {
        let date = calendar.startOfDay(for: date)
        let entries = entriesByHabitID(habits: habits, targetDates: [date], calendar: calendar)
        return dailyCompletionRatio(habits: habits, date: date, entries: entries, calendar: calendar)
    }

    func completionRatio(for habit: Habit, on date: Date, calendar: Calendar) -> Double {
        let date = calendar.startOfDay(for: date)
        guard habitSchedule.isScheduled(habit, on: date, calendar: calendar), habit.goalCount > 0 else {
            return 0
        }
        let entry = entriesByDate(for: habit, calendar: calendar)[date]
        if entry?.isSkipped == true { return 1 }
        return min(Double(entry?.completedCount ?? 0) / Double(habit.goalCount), 1)
    }

    func isComplete(habits: [Habit], on date: Date, calendar: Calendar) -> Bool {
        let date = calendar.startOfDay(for: date)
        let scheduled = habits.filter { habitSchedule.isScheduled($0, on: date, calendar: calendar) }
        guard !scheduled.isEmpty else { return false }
        return completionRatio(habits: scheduled, on: date, calendar: calendar) == 1
    }

    func isComplete(for habit: Habit, on date: Date, calendar: Calendar) -> Bool {
        let date = calendar.startOfDay(for: date)
        guard habitSchedule.isScheduled(habit, on: date, calendar: calendar), habit.goalCount > 0 else {
            return false
        }
        return entriesByDate(for: habit, calendar: calendar)[date]?.isCompleted ?? false
    }

    func dates(
        in component: Calendar.Component,
        containing date: Date,
        calendar: Calendar
    ) -> [Date] {
        guard let interval = calendar.dateInterval(of: component, for: date) else { return [] }
        var result: [Date] = []
        var currentDate = calendar.startOfDay(for: interval.start)

        while currentDate < interval.end {
            result.append(currentDate)
            guard let nextDate = calendar.date(byAdding: .day, value: 1, to: currentDate) else { break }
            currentDate = nextDate
        }
        return result
    }

    func completionRatio(habits: [Habit], dates: [Date], calendar: Calendar) -> Double {
        let targetDates = dates.map { calendar.startOfDay(for: $0) }
        let entries = entriesByHabitID(habits: habits, targetDates: Set(targetDates), calendar: calendar)
        let validDates = targetDates.filter { date in
            habits.contains {
                habitSchedule.isScheduled($0, on: date, calendar: calendar) &&
                entries[$0.id]?[date]?.isSkipped != true
            }
        }
        guard !validDates.isEmpty else { return 0 }

        let total = validDates.reduce(0.0) { result, date in
            result + dailyCompletionRatio(habits: habits, date: date, entries: entries, calendar: calendar)
        }
        return total / Double(validDates.count)
    }

    func completionRatio(for habit: Habit, dates: [Date], calendar: Calendar) -> Double {
        let targetDates = dates.map { calendar.startOfDay(for: $0) }
        let entries = entriesByDate(for: habit, calendar: calendar)
        let validDates = targetDates.filter {
            habitSchedule.isScheduled(habit, on: $0, calendar: calendar) && entries[$0]?.isSkipped != true
        }
        guard !validDates.isEmpty else { return 0 }

        let total = validDates.reduce(0.0) { result, date in
            guard habit.goalCount > 0 else { return result }
            let count = entries[date]?.completedCount ?? 0
            return result + min(Double(count) / Double(habit.goalCount), 1)
        }
        return total / Double(validDates.count)
    }

    func summary(for habit: Habit, dates: [Date], calendar: Calendar) -> HabitStatisticSummary {
        let scheduledDates = dates.map { calendar.startOfDay(for: $0) }
            .filter { habitSchedule.isScheduled(habit, on: $0, calendar: calendar) }
        guard !scheduledDates.isEmpty else { return .empty }

        let scheduledSet = Set(scheduledDates)
        let archivedDay = habit.archivedAt.map { calendar.startOfDay(for: $0) }
        let entries = habit.entries.reduce(into: [Date: HabitEntry]()) { result, entry in
            let day = calendar.startOfDay(for: entry.date)
            guard scheduledSet.contains(day), archivedDay.map({ day <= $0 }) ?? true else { return }
            result[day] = entry
        }
        let skippedDates = scheduledDates.filter { entries[$0]?.isSkipped == true }
        let activeDates = scheduledDates.filter { entries[$0]?.isSkipped != true }
        let completedCount = activeDates.reduce(0) {
            $0 + min(entries[$1]?.completedCount ?? 0, habit.goalCount)
        }
        let completedDays = activeDates.filter {
            habit.goalCount > 0 && (entries[$0]?.completedCount ?? 0) >= habit.goalCount
        }.count
        let targetCount = activeDates.count * habit.goalCount

        return HabitStatisticSummary(
            progress: targetCount == 0 ? 0 : min(Double(completedCount) / Double(targetCount), 1),
            scheduledDays: activeDates.count,
            completedDays: completedDays,
            skippedDays: skippedDates.count,
            totalCompletedCount: completedCount,
            totalTargetCount: targetCount
        )
    }

    func aggregateSummary(habits: [Habit], dates: [Date], calendar: Calendar) -> HabitStatisticSummary {
        let targetDates = dates.map { calendar.startOfDay(for: $0) }
        let entries = entriesByHabitID(habits: habits, targetDates: Set(targetDates), calendar: calendar)
        var scheduledDays = 0
        var completedDays = 0
        var skippedDays = 0
        var completedCount = 0
        var targetCount = 0
        var totalRatio = 0.0
        var scheduledHabitCount = 0

        for date in targetDates {
            let scheduled = habits.filter {
                habitSchedule.isScheduled($0, on: date, calendar: calendar) && $0.goalCount > 0
            }
            guard !scheduled.isEmpty else { continue }

            var hasSkipped = false
            let active = scheduled.filter { habit in
                let skipped = entries[habit.id]?[date]?.isSkipped == true
                hasSkipped = hasSkipped || skipped
                return !skipped
            }
            if hasSkipped { skippedDays += 1 }
            guard !active.isEmpty else { continue }
            scheduledDays += 1

            var dayComplete = true
            for habit in active {
                let count = min(entries[habit.id]?[date]?.completedCount ?? 0, habit.goalCount)
                let ratio = min(Double(count) / Double(habit.goalCount), 1)
                completedCount += count
                targetCount += habit.goalCount
                totalRatio += ratio
                scheduledHabitCount += 1
                if ratio < 1 { dayComplete = false }
            }
            if dayComplete { completedDays += 1 }
        }

        return HabitStatisticSummary(
            progress: scheduledHabitCount == 0 ? 0 : totalRatio / Double(scheduledHabitCount),
            scheduledDays: scheduledDays,
            completedDays: completedDays,
            skippedDays: skippedDays,
            totalCompletedCount: completedCount,
            totalTargetCount: targetCount
        )
    }
}

private extension HabitStatisticsCalculator {
    func entriesByHabitID(
        habits: [Habit],
        targetDates: Set<Date>,
        calendar: Calendar
    ) -> [UUID: [Date: HabitEntry]] {
        habits.reduce(into: [:]) { result, habit in
            for entry in habit.entries {
                let date = calendar.startOfDay(for: entry.date)
                if targetDates.contains(date) { result[habit.id, default: [:]][date] = entry }
            }
        }
    }

    func entriesByDate(for habit: Habit, calendar: Calendar) -> [Date: HabitEntry] {
        habit.entries.reduce(into: [:]) {
            $0[calendar.startOfDay(for: $1.date)] = $1
        }
    }

    func dailyCompletionRatio(
        habits: [Habit],
        date: Date,
        entries: [UUID: [Date: HabitEntry]],
        calendar: Calendar
    ) -> Double {
        let scheduled = habits.filter { habitSchedule.isScheduled($0, on: date, calendar: calendar) }
        guard !scheduled.isEmpty else { return 0 }
        var activeCount = 0
        let total = scheduled.reduce(0.0) { result, habit in
            guard habit.goalCount > 0, entries[habit.id]?[date]?.isSkipped != true else { return result }
            activeCount += 1
            let count = entries[habit.id]?[date]?.completedCount ?? 0
            return result + min(Double(count) / Double(habit.goalCount), 1)
        }
        return activeCount == 0 ? 1 : total / Double(activeCount)
    }
}

private extension HabitStatisticSummary {
    static let empty = HabitStatisticSummary(
        progress: 0,
        scheduledDays: 0,
        completedDays: 0,
        skippedDays: 0,
        totalCompletedCount: 0,
        totalTargetCount: 0
    )
}
