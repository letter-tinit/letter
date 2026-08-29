//
//  HabitViewModel.swift
//  Letter
//
//  Created by TiniT on 28/4/26.
//

import Observation
import Foundation
import SwiftData

@Observable
final class HabitViewModel {
    private struct HabitListQueryKey: Equatable {
        let date: Date
        let today: Date
    }

    // MARK: - Dependencies
    private let repository: any HabitRepository
    private let homeQuery: any HabitHomeQuerying
    private let habitEntryMutationPolicy = HabitEntryMutationPolicy()
    private let habitStreakCalculator = HabitStreakCalculator()
    private let notificationScheduler: any HabitNotificationScheduling
    
    var homeTitle: String = AppString.Home.today
    var habits: [Habit] = []
    @ObservationIgnored private var filteredHabitQueryKey: HabitListQueryKey?
    private(set) var filteredHabits: [HabitListItem] = []

    private(set) var selectedDate: Date = Date()
    private(set) var weekStartsOnMonday: Bool

    func refreshFilteredHabits(force: Bool = false) {
        let calendar = AppCalendar.current
        let targetDate = calendar.startOfDay(for: selectedDate)
        let today = calendar.startOfDay(for: Date())

        let key = HabitListQueryKey(date: targetDate, today: today)
        guard force || filteredHabitQueryKey != key else {
            return
        }

        do {
            filteredHabits = try homeQuery.habitItems(
                on: targetDate,
                relativeTo: today,
                calendar: calendar
            )
        } catch {
            Logger.error("Failed to load Habit home items: \(error)")
            filteredHabits = []
        }

        filteredHabitQueryKey = key
    }
    var orderedWeekdays: [Int] {
        weekStartsOnMonday
        ? [1, 2, 3, 4, 5, 6, 0]
        : [0, 1, 2, 3, 4, 5, 6]
    }
    
    // MARK: - Constructor
    init(
        repository: any HabitRepository,
        homeQuery: any HabitHomeQuerying,
        notificationScheduler: any HabitNotificationScheduling,
        weekStartsOnMonday: Bool = AppCalendar.weekStartsOnMonday
    ) {
        self.repository = repository
        self.homeQuery = homeQuery
        self.notificationScheduler = notificationScheduler
        self.weekStartsOnMonday = weekStartsOnMonday
        fetchHabits()
    }
}

// MARK: - Home
extension HabitViewModel {
    func refreshLocalizedText() {
        homeTitle = selectedDate.isToday()
        ? AppString.Home.today
        : selectedDate.toString(withFormat: .dayNameWithNo)
    }
    
    func backToday() {
        changeSelectedDate(Date())
    }
    
    func changeSelectedDate(_ date: Date) {
        selectedDate = date
        refreshFilteredHabits(force: true)
        if selectedDate.isToday() {
            homeTitle = AppString.Home.today
        } else {
            homeTitle = selectedDate.toString(withFormat: .dayNameWithNo)
        }
    }
    
    func weekDaySummaries(for dates: [Date]) -> [WeekDaySummary] {
        let calendar = AppCalendar.current
        let progress: [HabitDayProgress]

        do {
            progress = try homeQuery.dayProgress(for: dates, calendar: calendar)
        } catch {
            Logger.error("Failed to load Habit day progress: \(error)")
            progress = []
        }

        return progress.map {
            WeekDaySummary(
                date: $0.date,
                isSelected: calendar.isDate($0.date, inSameDayAs: selectedDate),
                isToday: calendar.isDateInToday($0.date),
                isComplete: $0.isComplete,
                completionRatio: $0.completionRatio
            )
        }
    }
}

// MARK: - Reload
extension HabitViewModel {
    func setWeekStartsOnMonday(_ enabled: Bool) {
        weekStartsOnMonday = enabled
    }
}

// MARK: - Habits
extension HabitViewModel {
    func fetchHabits() {
        do {
            habits = try repository.fetchHabits()
        } catch {
            Logger.error("Failed to fetch habits: \(error)")
            habits = []
        }
        refreshFilteredHabits(force: true)
    }
    
    func habit(id: UUID) -> Habit? {
        habits.first {
            $0.modelContext != nil && !$0.isDeleted && $0.id == id
        }
    }
}

// MARK: - Habit Entries
extension HabitViewModel {
    func updateHabitEntry(_ habit: Habit, completedCount: Int, note: String? = nil) {
        let calendar = AppCalendar.current
        let mutation = habitEntryMutationPolicy.updateProgress(
            for: habit,
            on: selectedDate,
            completedCount: completedCount,
            note: note,
            calendar: calendar
        )
        applyEntryMutation(mutation, to: habit)
    }
    
    func skipHabitEntry(_ habit: Habit) {
        let calendar = AppCalendar.current
        let mutation = habitEntryMutationPolicy.skip(
            habit,
            on: selectedDate,
            calendar: calendar
        )
        applyEntryMutation(mutation, to: habit)
    }
    
    func resetHabitEntry(_ habit: Habit) {
        let calendar = AppCalendar.current
        let mutation = habitEntryMutationPolicy.reset(
            habit,
            on: selectedDate,
            calendar: calendar
        )
        if case .updated = mutation {
            Haptic.warning()
        }
        applyEntryMutation(mutation, to: habit)
    }
}

// MARK: - Streak Helpers

private extension HabitViewModel {
    func applyEntryMutation(_ mutation: HabitEntryMutation, to habit: Habit) {
        switch mutation {
        case .unchanged:
            return
        case .rejected:
            Haptic.warning()
            return
        case .updated:
            break
        case .inserted(let entry):
            repository.addEntry(entry)
        }

        updateStreaks(for: habit)
        refreshFilteredHabits(force: true)
        _ = save()
    }

    func updateStreaks(for habit: Habit) {
        let result = habitStreakCalculator.calculate(for: habit, calendar: AppCalendar.current)
        habit.currentStreak = result.currentStreak
        habit.longestStreak = result.longestStreak
        habit.lastCompletedDate = result.lastCompletedDate
    }
    
}

// MARK: - Scheduling
extension HabitViewModel {
    func rescheduleHabitNotifications() {
        for habit in habits {
            notificationScheduler.rescheduleNotifications(for: habit)
        }
    }
}

// MARK: - Persistence
private extension HabitViewModel {
    func save() -> Bool {
        do {
            try repository.save()
            return true
        } catch {
            Logger.error("Failed to save context: \(error)")
            return false
        }
    }
}
