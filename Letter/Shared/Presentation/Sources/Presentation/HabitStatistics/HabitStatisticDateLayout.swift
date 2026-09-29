//
//  HabitStatisticDateLayout.swift
//  Letter
//
//  Created by Codex on 29/9/26.
//

import Foundation
import Domain

public enum HabitStatisticDateLayout {
    public static func weekDates(_ dates: [Date]) -> [Date] {
        dates
    }

    public static func monthDates(_ dates: [Date?]) -> [Date?] {
        dates
    }

    public static func yearWeeks(
        _ weeks: [[Date]],
        dayStatistics: [Date: HabitDayStatistic],
        calendar: Calendar
    ) -> [[Date]] {
        weeks.filter { week in
            week.contains {
                dayStatistics[calendar.startOfDay(for: $0)]?.isAvailable == true
            }
        }
    }
}
