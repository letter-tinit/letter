//
//  HabitViewModel.swift
//  Letter
//
//  Created by TiniT on 28/4/26.
//

import Observation
import Foundation
import Domain
import Core
import Utility
import Styleguide

@Observable
@MainActor
public final class HabitViewModel {
    // MARK: - Dependencies
    private let useCase: any HabitHomeUseCase
    private let calendarPreferences: CalendarPreferences
    private var habits: [HabitSnapshot] = []
    
    // MARK: Variable
    public var title: String = "habit.home.today".localized
    @ObservationIgnored private var filteredHabitQueryKey: HabitListQueryKey?
    private(set) var filteredHabits: [HabitListItem] = []
    
    private(set) var selectedDate: Date = Date()
    public var weekStartsOnMonday: Bool {
        calendarPreferences.weekStartsOnMonday
    }
    
    public var calendar: Calendar {
        calendarPreferences.calendar
    }
    
    // MARK: - Constructor
    public init(
        useCase: any HabitHomeUseCase,
        calendarPreferences: CalendarPreferences
    ) {
        self.useCase = useCase
        self.calendarPreferences = calendarPreferences
        fetchHabits()
    }
}

// MARK: - Public API
public extension HabitViewModel {
    public func refreshFilteredHabits(force: Bool = false) {
        let calendar = calendarPreferences.calendar
        let targetDate = calendar.startOfDay(for: selectedDate)
        let today = calendar.startOfDay(for: Date())
        
        let key = HabitListQueryKey(date: targetDate, today: today)
        guard force || filteredHabitQueryKey != key else {
            return
        }
        
        do {
            filteredHabits = try useCase.habitItems(
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
    
    public func refreshLocalizedText() {
        title = selectedDate.isToday()
        ? "habit.home.today".localized
        : selectedDate.toString(withFormat: .dayNameWithNo)
    }
    
    public func backToday() {
        changeSelectedDate(Date())
    }
    
    public func changeSelectedDate(_ date: Date) {
        selectedDate = date
        refreshFilteredHabits(force: true)
        refreshLocalizedText()
    }
    
    public func weekDaySummaries(for dates: [Date]) -> [WeekDaySummary] {
        let calendar = calendarPreferences.calendar
        let progress: [HabitDayProgress]
        
        do {
            progress = try useCase.dayProgress(for: dates, calendar: calendar)
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
    
    public func fetchHabits() {
        do {
            habits = try useCase.fetchHabits()
        } catch {
            Logger.error("Failed to fetch habits: \(error)")
            habits = []
        }
        refreshFilteredHabits(force: true)
    }
    
    public func habit(id: UUID) -> HabitSnapshot? {
        habits.first { $0.id == id }
    }
    
    public func updateHabitEntry(
        _ habit: HabitSnapshot,
        completedCount: Int,
        note: String? = nil
    ) {
        let calendar = calendarPreferences.calendar
        performEntryChange {
            try useCase.updateEntry(
                for: habit,
                on: selectedDate,
                completedCount: completedCount,
                note: note,
                calendar: calendar,
                now: Date()
            )
        }
    }
    
    public func skipHabitEntry(_ habit: HabitSnapshot) {
        let calendar = calendarPreferences.calendar
        performEntryChange {
            try useCase.skipEntry(
                for: habit,
                on: selectedDate,
                calendar: calendar,
                now: Date()
            )
        }
    }
    
    public func resetHabitEntry(_ habit: HabitSnapshot) {
        let calendar = calendarPreferences.calendar
        performEntryChange(warnsWhenUpdated: true) {
            try useCase.resetEntry(
                for: habit,
                on: selectedDate,
                calendar: calendar,
                now: Date()
            )
        }
    }
}

// MARK: - Private Helpers
private extension HabitViewModel {
    public func performEntryChange(
        warnsWhenUpdated: Bool = false,
        _ operation: () throws -> HabitEntryChange
    ) {
        do {
            switch try operation() {
            case .unchanged:
                return
            case .rejected:
                Haptic.warning()
            case .updated:
                if warnsWhenUpdated { Haptic.warning() }
                fetchHabits()
            }
        } catch {
            Logger.error("Failed to update Habit entry: \(error)")
        }
    }
}

// MARK: - Scheduling
public extension HabitViewModel {
    public func rescheduleHabitNotifications() {
        useCase.rescheduleNotifications(for: habits)
    }
}

// MARK: Model
public extension HabitViewModel {
    private struct HabitListQueryKey: Equatable {
        let date: Date
        let today: Date
    }
}
