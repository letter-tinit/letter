//
//  HabitStatisticsViewModel.swift
//  Letter
//

import Foundation
import Observation

@Observable
@MainActor
final class HabitStatisticsViewModel {
    private let repository: any HabitRepository
    private let statisticsCalculator: HabitStatisticsCalculator
    private let calendarPreferences: CalendarPreferences

    private(set) var habits: [Habit] = []
    private(set) var usesCompactStatisticsView = false
    @ObservationIgnored private var userProfile: UserProfile?

    var orderedWeekdays: [Int] {
        calendarPreferences.orderedWeekdays
    }

    var calendar: Calendar {
        calendarPreferences.calendar
    }

    init(repository: any HabitRepository, calendarPreferences: CalendarPreferences) {
        self.repository = repository
        self.calendarPreferences = calendarPreferences
        statisticsCalculator = HabitStatisticsCalculator()
    }

    func reload() {
        do {
            habits = try repository.fetchHabits()
        } catch {
            Logger.error("Failed to fetch habit statistics data: \(error)")
            habits = []
        }

        do {
            userProfile = try repository.fetchUserProfile()
            usesCompactStatisticsView = userProfile?.usesSimplifiedStatisticsMode ?? false
        } catch {
            Logger.error("Failed to fetch statistics display mode: \(error)")
            userProfile = nil
            usesCompactStatisticsView = false
        }
    }

    func toggleCompactStatisticsView() {
        let newValue = !usesCompactStatisticsView

        do {
            if userProfile == nil {
                userProfile = try repository.fetchUserProfile()
            }

            guard let userProfile else { return }
            userProfile.usesSimplifiedStatisticsMode = newValue
            try repository.save()
            usesCompactStatisticsView = newValue
        } catch {
            repository.rollback()
            Logger.error("Failed to update statistics display mode: \(error)")
        }
    }

    func dayStatistics(for habit: Habit, dates: [Date]) -> [Date: HabitDayStatistic] {
        statisticsCalculator.dayStatistics(
            for: habit,
            dates: dates,
            calendar: calendarPreferences.calendar
        )
    }

    func aggregateDayStatistics(dates: [Date]) -> [Date: HabitDayStatistic] {
        statisticsCalculator.aggregateDayStatistics(
            habits: habits,
            dates: dates,
            calendar: calendarPreferences.calendar
        )
    }

    func monthDates(containing date: Date) -> [Date] {
        statisticsCalculator.dates(
            in: .month,
            containing: date,
            calendar: calendarPreferences.calendar
        )
    }

    func weekDates(containing date: Date) -> [Date] {
        statisticsCalculator.dates(
            in: .weekOfYear,
            containing: date,
            calendar: calendarPreferences.calendar
        )
    }

    func statisticSummary(
        for habit: Habit,
        scope: StatisticsScope,
        containing date: Date
    ) -> HabitStatisticSummary {
        statisticsCalculator.summary(
            for: habit,
            dates: dates(scope: scope, containing: date),
            calendar: calendarPreferences.calendar
        )
    }

    func statisticSummary(
        scope: StatisticsScope,
        containing date: Date
    ) -> HabitStatisticSummary {
        statisticsCalculator.aggregateSummary(
            habits: habits,
            dates: dates(scope: scope, containing: date),
            calendar: calendarPreferences.calendar
        )
    }

    func dates(scope: StatisticsScope, containing date: Date) -> [Date] {
        switch scope {
        case .week:
            weekDates(containing: date)
        case .month:
            monthDates(containing: date)
        case .year:
            yearDates(containing: date)
        }
    }

    private func yearDates(containing date: Date) -> [Date] {
        statisticsCalculator.dates(
            in: .year,
            containing: date,
            calendar: calendarPreferences.calendar
        )
    }
}
