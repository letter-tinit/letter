//
//  HabitSchedule.swift
//  Habit
//
//  Created by Tín Nguyễn on 18/8/26.
//

import Foundation

struct HabitSchedule {
    func isScheduled(
        _ habit: Habit,
        on date: Date,
        calendar: Calendar
    ) -> Bool {
        let day = calendar.startOfDay(for: date)
        let startDay = calendar.startOfDay(for: habit.effectiveStartDate)

        guard day >= startDay else {
            return false
        }

        if let endDate = habit.endDate {
            let endDay = calendar.startOfDay(for: endDate)
            guard day <= endDay else {
                return false
            }
        }

        if let archivedAt = habit.archivedAt {
            let archivedDay = calendar.startOfDay(for: archivedAt)
            guard day <= archivedDay else {
                return false
            }
        }

        let weekday = calendar.component(.weekday, from: day) - 1

        switch habit.frequency {
        case .daily:
            return true
        case .weekday:
            return (1...5).contains(weekday)
        case .weekend:
            return weekday == 0 || weekday == 6
        case .custom:
            return habit.targetDaysOfWeek.contains(weekday)
        }
    }
}
