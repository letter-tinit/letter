//
//  HabitStatisticsViewModel.swift
//  Letter
//

import Foundation
import Observation
import Domain
import Utility
import Styleguide

@Observable
@MainActor
public final class HabitStatisticsViewModel {
    private let useCase: any HabitStatisticsUseCase
    private let calendarPreferences: CalendarPreferences

    private(set) var habits: [HabitSnapshot] = []
    private(set) var usesCompactStatisticsView = false

    public var orderedWeekdays: [Int] {
        calendarPreferences.orderedWeekdays
    }

    public var calendar: Calendar {
        calendarPreferences.calendar
    }

    public init(
        useCase: any HabitStatisticsUseCase,
        calendarPreferences: CalendarPreferences
    ) {
        self.useCase = useCase
        self.calendarPreferences = calendarPreferences
    }

    public func reload() {
        do {
            let data = try useCase.load()
            habits = data.habits
            usesCompactStatisticsView = data.usesCompactView
        } catch {
            Logger.error("Failed to fetch HabitSnapshot statistics data: \(error)")
            habits = []
            usesCompactStatisticsView = false
        }
    }

    public func toggleCompactStatisticsView() {
        let newValue = !usesCompactStatisticsView

        do {
            try useCase.setCompactViewEnabled(newValue)
            usesCompactStatisticsView = newValue
        } catch {
            Logger.error("Failed to update statistics display mode: \(error)")
        }
    }

    public func dayStatistics(for habit: HabitSnapshot, dates: [Date]) -> [Date: HabitDayStatistic] {
        useCase.dayStatistics(
            for: habit,
            dates: dates,
            calendar: calendarPreferences.calendar
        )
    }

    public func aggregateDayStatistics(dates: [Date]) -> [Date: HabitDayStatistic] {
        useCase.aggregateDayStatistics(
            habits: habits,
            dates: dates,
            calendar: calendarPreferences.calendar
        )
    }

    public func monthDates(containing date: Date) -> [Date] {
        useCase.dates(
            in: .month,
            containing: date,
            calendar: calendarPreferences.calendar
        )
    }

    public func weekDates(containing date: Date) -> [Date] {
        useCase.dates(
            in: .weekOfYear,
            containing: date,
            calendar: calendarPreferences.calendar
        )
    }

    public func statisticSummary(
        for habit: HabitSnapshot,
        scope: StatisticsScope,
        containing date: Date
    ) -> HabitStatisticSummary {
        useCase.summary(
            for: habit,
            dates: dates(scope: scope, containing: date),
            calendar: calendarPreferences.calendar
        )
    }

    public func statisticSummary(
        scope: StatisticsScope,
        containing date: Date
    ) -> HabitStatisticSummary {
        useCase.aggregateSummary(
            habits: habits,
            dates: dates(scope: scope, containing: date),
            calendar: calendarPreferences.calendar
        )
    }

    public func dates(scope: StatisticsScope, containing date: Date) -> [Date] {
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
        useCase.dates(
            in: .year,
            containing: date,
            calendar: calendarPreferences.calendar
        )
    }
}
