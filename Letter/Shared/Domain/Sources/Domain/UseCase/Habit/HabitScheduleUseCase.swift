//
//  HabitSchedule.swift
//  Letter
//
//  Created by Tín Nguyễn on 18/8/26.
//

import Foundation
import Utility

public protocol HabitScheduleUseCase {
    func isScheduled<Schedule: HabitScheduling>(
        _ habit: Schedule,
        on date: Date,
        calendar: Calendar
    ) -> Bool
}

public struct ImpHabitScheduleUseCase: HabitScheduleUseCase {
    public func isScheduled(
        _ habit: some HabitScheduling,
        on date: Date,
        calendar: Calendar
    ) -> Bool {
        isScheduled(
            startDate: habit.effectiveStartDate,
            endDate: habit.endDate,
            archivedAt: habit.archivedAt,
            frequency: habit.frequency,
            targetDaysOfWeek: habit.targetDaysOfWeek,
            on: date,
            calendar: calendar
        )
    }

    private func isScheduled(
        startDate: Date,
        endDate: Date?,
        archivedAt: Date?,
        frequency: HabitFrequency,
        targetDaysOfWeek: [Int],
        on date: Date,
        calendar: Calendar
    ) -> Bool {
        let day = calendar.startOfDay(for: date)
        let startDay = calendar.startOfDay(for: startDate)

        guard day >= startDay else {
            return false
        }

        if let endDate {
            let endDay = calendar.startOfDay(for: endDate)
            guard day <= endDay else {
                return false
            }
        }

        if let archivedAt {
            let archivedDay = calendar.startOfDay(for: archivedAt)
            guard day <= archivedDay else {
                return false
            }
        }

        let weekday = calendar.component(.weekday, from: day) - 1

        switch frequency {
        case .daily:
            return true
        case .weekday:
            return (1...5).contains(weekday)
        case .weekend:
            return weekday == 0 || weekday == 6
        case .custom:
            return targetDaysOfWeek.contains(weekday)
        }
    }
}
