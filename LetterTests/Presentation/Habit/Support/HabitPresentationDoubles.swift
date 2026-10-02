import Foundation
@testable import Domain
@testable import Presentation

enum HabitPresentationError: LocalizedError {
    case unavailable
    var errorDescription: String? { "Habit service unavailable" }
}

@MainActor
final class HabitFormSpy: HabitFormUseCase {
    var error: Error?
    var savedID = UUID()
    var submissions: [(mode: HabitFormMode, draft: HabitDraft, calendar: Calendar)] = []
    func loadHabit(id: UUID) throws -> HabitSnapshot? { nil }
    func save(mode: HabitFormMode, draft: HabitDraft, calendar: Calendar, now: Date) throws -> UUID {
        submissions.append((mode, draft, calendar))
        if let error { throw error }
        return savedID
    }
}

@MainActor
final class HabitDetailSpy: HabitDetailUseCase {
    var habit: HabitSnapshot?
    var error: Error?
    var loadedIDs: [UUID] = []
    var deletedIDs: [UUID] = []
    var completions: [(id: UUID, date: Date)] = []
    func load(habitID: UUID) throws -> HabitDetailData? {
        loadedIDs.append(habitID)
        if let error { throw error }
        return habit.map { HabitDetailData(habit: $0) }
    }
    func delete(habitID: UUID) throws {
        deletedIDs.append(habitID)
        if let error { throw error }
    }
    func complete(habitID: UUID, completedAt: Date, calendar: Calendar) throws {
        completions.append((habitID, completedAt))
        if let error { throw error }
    }
}

@MainActor
final class HabitHomeSpy: HabitHomeUseCase {
    var habits: [HabitSnapshot] = []
    var fetchError: Error?
    var itemsError: Error?
    var items: [HabitListItem] = []
    var entryError: Error?
    var change = HabitEntryChange.unchanged
    var fetchCount = 0
    var itemDates: [Date] = []
    var progressCount = 0
    var progress: [HabitDayProgress] = []
    var progressHabitIDs: [UUID] = []
    var progressCalendars: [Calendar] = []
    var entries: [(kind: String, id: UUID, date: Date, count: Int?, note: String?)] = []
    var scheduledIDs: [UUID] = []
    func fetchHabits() throws -> [HabitSnapshot] {
        fetchCount += 1
        if let fetchError { throw fetchError }
        return habits
    }
    func habitItems(on date: Date, relativeTo today: Date, calendar: Calendar) throws -> [HabitListItem] {
        itemDates.append(date)
        if let itemsError { throw itemsError }
        return items
    }
    func dayProgress(for dates: [Date], habits: [HabitSnapshot], calendar: Calendar) -> [HabitDayProgress] {
        progressCount += 1
        progressHabitIDs = habits.map(\.id)
        progressCalendars.append(calendar)
        return progress
    }
    func updateEntry(for habit: HabitSnapshot, on date: Date, completedCount: Int, note: String?, calendar: Calendar, now: Date) throws -> HabitEntryChange {
        entries.append(("update", habit.id, date, completedCount, note))
        if let entryError { throw entryError }
        return change
    }
    func skipEntry(for habit: HabitSnapshot, on date: Date, calendar: Calendar, now: Date) throws -> HabitEntryChange {
        entries.append(("skip", habit.id, date, nil, nil))
        if let entryError { throw entryError }
        return change
    }
    func resetEntry(for habit: HabitSnapshot, on date: Date, calendar: Calendar, now: Date) throws -> HabitEntryChange {
        entries.append(("reset", habit.id, date, nil, nil))
        if let entryError { throw entryError }
        return change
    }
    func rescheduleNotifications(for habits: [HabitSnapshot]) { scheduledIDs = habits.map(\.id) }
}

@MainActor
final class HabitStatisticsSpy: HabitStatisticsUseCase {
    var habits: [HabitSnapshot] = []
    var compact = false
    var loadError: Error?
    var writeError: Error?
    var writes: [Bool] = []
    var availabilityCalls = 0
    var requestedComponents: [Calendar.Component] = []
    var requestedCalendars: [Calendar] = []
    var returnedDates = [HabitTestSupport.date(2024, 1, 1)]
    var summaryDates: [Date] = []
    var aggregateIDs: [UUID] = []
    var requestedHabitID: UUID?
    var returnedStatistics: [Date: HabitDayStatistic] = [:]
    var returnedSummary = HabitStatisticSummary(
        progress: 0.4, scheduledDays: 5, completedDays: 2, skippedDays: 1,
        totalCompletedCount: 4, totalTargetCount: 10
    )
    func load() throws -> HabitStatisticsData {
        if let loadError { throw loadError }
        return HabitStatisticsData(habits: habits, usesCompactView: compact)
    }
    func setCompactViewEnabled(_ enabled: Bool) throws {
        writes.append(enabled)
        if let writeError { throw writeError }
        compact = enabled
    }
    func availability(habits: [HabitSnapshot], today: Date, calendar: Calendar) -> HabitStatisticsAvailability {
        availabilityCalls += 1
        return HabitStatisticsAvailability(habits: habits, today: today, calendar: calendar)
    }
    func dates(in component: Calendar.Component, containing date: Date, calendar: Calendar) -> [Date] {
        requestedComponents.append(component)
        requestedCalendars.append(calendar)
        return returnedDates
    }
    func dayStatistics(for habit: HabitSnapshot, dates: [Date], calendar: Calendar) -> [Date: HabitDayStatistic] {
        requestedHabitID = habit.id
        summaryDates = dates
        return returnedStatistics
    }
    func aggregateDayStatistics(habits: [HabitSnapshot], dates: [Date], calendar: Calendar) -> [Date: HabitDayStatistic] {
        aggregateIDs = habits.map(\.id)
        summaryDates = dates
        return returnedStatistics
    }
    func summary(for habit: HabitSnapshot, dates: [Date], calendar: Calendar) -> HabitStatisticSummary {
        requestedHabitID = habit.id
        summaryDates = dates
        return returnedSummary
    }
    func aggregateSummary(habits: [HabitSnapshot], dates: [Date], calendar: Calendar) -> HabitStatisticSummary {
        aggregateIDs = habits.map(\.id)
        summaryDates = dates
        return returnedSummary
    }
}

/// Value snapshots for Presentation mapping cases; no app or persistence setup.
enum HabitPresentationSupport {
    static func habit(goalType: GoalType = .count, reminders: [HabitReminderConfiguration]) -> HabitSnapshot {
        let base = HabitTestSupport.makeHabit()
        return HabitSnapshot(
            id: base.id, name: base.name, habitDescription: "Evening reading",
            icon: base.icon, colorHex: base.colorHex, createdAt: base.createdAt,
            sortOrder: base.sortOrder, startDate: base.startDate, endDate: nil,
            completedAt: nil, frequency: base.frequency,
            targetDaysOfWeek: base.targetDaysOfWeek, goalType: goalType,
            goalCount: base.goalCount, goalUnit: base.goalUnit,
            currentStreak: 0, longestStreak: 0, lastCompletedDate: nil,
            reminders: reminders, entries: []
        )
    }
}
