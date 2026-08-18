//
//  AppCalendar.swift
//  Habit
//
//  Created by TiniT on 19/5/26.
//

import Foundation

struct AppCalendar {
    private static let weekStartsOnMondayKey = "weekStartsOnMonday"

    static var weekStartsOnMonday: Bool {
        get {
            guard UserDefaults.standard.object(forKey: weekStartsOnMondayKey) != nil else {
                return true
            }

            return UserDefaults.standard.bool(forKey: weekStartsOnMondayKey)
        }
        set {
            UserDefaults.standard.set(newValue, forKey: weekStartsOnMondayKey)
        }
    }

    static var current: Calendar {
        var calendar = Calendar.current
        calendar.firstWeekday = weekStartsOnMonday ? 2 : 1
        return calendar
    }
}
