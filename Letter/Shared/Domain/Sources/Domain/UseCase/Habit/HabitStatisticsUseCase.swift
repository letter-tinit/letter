import Foundation
import Utility

public struct HabitStatisticsData {
    public let habits: [HabitSnapshot]
    public let usesCompactView: Bool
}

@MainActor
public protocol HabitStatisticsUseCase {
    func load() throws -> HabitStatisticsData
    func setCompactViewEnabled(_ enabled: Bool) throws
    func dayStatistics(
        for habit: HabitSnapshot,
        dates: [Date],
        calendar: Calendar
    ) -> [Date: HabitDayStatistic]
    func aggregateDayStatistics(
        habits: [HabitSnapshot],
        dates: [Date],
        calendar: Calendar
    ) -> [Date: HabitDayStatistic]
    func dates(
        in component: Calendar.Component,
        containing date: Date,
        calendar: Calendar
    ) -> [Date]
    func summary(
        for habit: HabitSnapshot,
        dates: [Date],
        calendar: Calendar
    ) -> HabitStatisticSummary
    func aggregateSummary(
        habits: [HabitSnapshot],
        dates: [Date],
        calendar: Calendar
    ) -> HabitStatisticSummary
}

@MainActor
public final class ImpHabitStatisticsUseCase: HabitStatisticsUseCase {
    private let repository: any HabitRepository
    private let habitSchedule = ImpHabitScheduleUseCase()

    public init(repository: any HabitRepository) {
        self.repository = repository
    }

    public func load() throws -> HabitStatisticsData {
        return HabitStatisticsData(
            habits: try repository.fetchHabitSnapshots(),
            usesCompactView: try repository.fetchUsesCompactStatisticsView()
        )
    }

    public func setCompactViewEnabled(_ enabled: Bool) throws {
        try repository.setUsesCompactStatisticsView(enabled)
    }

    public func completionRatio(habits: [HabitSnapshot], on date: Date, calendar: Calendar) -> Double {
        let date = calendar.startOfDay(for: date)
        let entries = entriesByHabitID(habits: habits, targetDates: [date], calendar: calendar)
        return dailyCompletionRatio(habits: habits, date: date, entries: entries, calendar: calendar)
    }

    public func completionRatio(for habit: HabitSnapshot, on date: Date, calendar: Calendar) -> Double {
        let date = calendar.startOfDay(for: date)
        guard habitSchedule.isScheduled(habit, on: date, calendar: calendar), habit.goalCount > 0 else {
            return 0
        }
        let entry = entriesByDate(for: habit, calendar: calendar)[date]
        if entry?.isSkipped == true { return 1 }
        return min(Double(entry?.completedCount ?? 0) / Double(habit.goalCount), 1)
    }

    public func dayStatistics(
        for habit: HabitSnapshot,
        dates: [Date],
        calendar: Calendar
    ) -> [Date: HabitDayStatistic] {
        let normalizedDates = dates.map { calendar.startOfDay(for: $0) }
        let targetDates = Set(normalizedDates)
        let entries = habit.entries.reduce(into: [Date: HabitEntrySnapshot]()) { result, entry in
            let day = calendar.startOfDay(for: entry.date)
            if targetDates.contains(day) {
                result[day] = entry
            }
        }

        return normalizedDates.reduce(into: [:]) { result, day in
            let isScheduled = habitSchedule.isScheduled(habit, on: day, calendar: calendar)
            let entry = entries[day]
            let isSkipped = isScheduled && entry?.isSkipped == true
            let progress: Double

            if isScheduled, !isSkipped, habit.goalCount > 0 {
                progress = min(Double(entry?.completedCount ?? 0) / Double(habit.goalCount), 1)
            } else {
                progress = 0
            }

            result[day] = HabitDayStatistic(
                isScheduled: isScheduled,
                isSkipped: isSkipped,
                progress: progress
            )
        }
    }

    public func aggregateDayStatistics(
        habits: [HabitSnapshot],
        dates: [Date],
        calendar: Calendar
    ) -> [Date: HabitDayStatistic] {
        let normalizedDates = dates.map { calendar.startOfDay(for: $0) }
        let entries = entriesByHabitID(
            habits: habits,
            targetDates: Set(normalizedDates),
            calendar: calendar
        )

        return normalizedDates.reduce(into: [:]) { result, day in
            let scheduled = habits.filter {
                habitSchedule.isScheduled($0, on: day, calendar: calendar) && $0.goalCount > 0
            }
            guard !scheduled.isEmpty else {
                result[day] = HabitDayStatistic(isScheduled: false, isSkipped: false, progress: 0)
                return
            }

            let active = scheduled.filter { entries[$0.id]?[day]?.isSkipped != true }
            let progress: Double
            if active.isEmpty {
                progress = 0
            } else {
                progress = active.reduce(0.0) { total, habit in
                    let count = entries[habit.id]?[day]?.completedCount ?? 0
                    return total + min(Double(count) / Double(habit.goalCount), 1)
                } / Double(active.count)
            }

            result[day] = HabitDayStatistic(
                isScheduled: true,
                isSkipped: active.isEmpty,
                progress: progress
            )
        }
    }

    public func isComplete(habits: [HabitSnapshot], on date: Date, calendar: Calendar) -> Bool {
        let date = calendar.startOfDay(for: date)
        let scheduled = habits.filter { habitSchedule.isScheduled($0, on: date, calendar: calendar) }
        guard !scheduled.isEmpty else { return false }
        return completionRatio(habits: scheduled, on: date, calendar: calendar) == 1
    }

    public func isComplete(for habit: HabitSnapshot, on date: Date, calendar: Calendar) -> Bool {
        let date = calendar.startOfDay(for: date)
        guard habitSchedule.isScheduled(habit, on: date, calendar: calendar), habit.goalCount > 0 else {
            return false
        }
        return entriesByDate(for: habit, calendar: calendar)[date]?
            .isCompleted(goalCount: habit.goalCount) ?? false
    }

    public func dates(
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

    public func completionRatio(habits: [HabitSnapshot], dates: [Date], calendar: Calendar) -> Double {
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

    public func completionRatio(for habit: HabitSnapshot, dates: [Date], calendar: Calendar) -> Double {
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

    public func summary(for habit: HabitSnapshot, dates: [Date], calendar: Calendar) -> HabitStatisticSummary {
        let scheduledDates = dates.map { calendar.startOfDay(for: $0) }
            .filter { habitSchedule.isScheduled(habit, on: $0, calendar: calendar) }
        guard !scheduledDates.isEmpty else { return .empty }

        let scheduledSet = Set(scheduledDates)
        let archivedDay = habit.archivedAt.map { calendar.startOfDay(for: $0) }
        let entries = habit.entries.reduce(into: [Date: HabitEntrySnapshot]()) { result, entry in
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

    public func aggregateSummary(habits: [HabitSnapshot], dates: [Date], calendar: Calendar) -> HabitStatisticSummary {
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

private extension ImpHabitStatisticsUseCase {
    public func entriesByHabitID(
        habits: [HabitSnapshot],
        targetDates: Set<Date>,
        calendar: Calendar
    ) -> [UUID: [Date: HabitEntrySnapshot]] {
        habits.reduce(into: [:]) { result, habit in
            for entry in habit.entries {
                let date = calendar.startOfDay(for: entry.date)
                if targetDates.contains(date) { result[habit.id, default: [:]][date] = entry }
            }
        }
    }

    public func entriesByDate(for habit: HabitSnapshot, calendar: Calendar) -> [Date: HabitEntrySnapshot] {
        habit.entries.reduce(into: [:]) {
            $0[calendar.startOfDay(for: $1.date)] = $1
        }
    }

    public func dailyCompletionRatio(
        habits: [HabitSnapshot],
        date: Date,
        entries: [UUID: [Date: HabitEntrySnapshot]],
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
    public static let empty = HabitStatisticSummary(
        progress: 0,
        scheduledDays: 0,
        completedDays: 0,
        skippedDays: 0,
        totalCompletedCount: 0,
        totalTargetCount: 0
    )
}
