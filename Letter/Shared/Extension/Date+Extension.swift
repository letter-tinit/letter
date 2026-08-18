//
//  Date+Extension.swift
//  Habit
//
//  Created by TiniT on 29/4/26.
//

import Foundation

enum DateFormat {
    case classic // MMM d, yyyy
    case dayNameSymbol // T (Tuesday)
    case dayName // Tu (Tuesday)
    case dayNo // 26 (Number of day only)
    case dayNameWithNo // Tue, 26 (combine of day number and day name)
    case monthAndYear // July 2026
    case month
    case year
    case custom(String) // Passing date format throught string
    
    var value: String {
        switch self {
        case .classic:
            "MMM d, yyyy"
        case .dayNameSymbol:
            "EEEEE"
        case .dayName:
            "EEEEEE"
        case .dayNo:
            "d"
        case .dayNameWithNo:
            "EEE, d"
        case .monthAndYear:
            "MMMM yyyy"
        case .month:
            "MMMM"
        case .year:
            "YYYY"
        case .custom(let value):
            value
        }
    }
}

extension Date {
    var isInCurrentMonth: Bool {
        isInSameMonth(as: .now)
    }
    
    func isToday() -> Bool {
        return Calendar.current.isDateInToday(self)
    }
    
    func toString(withFormat dateFormat: DateFormat) -> String {
        let appLanguage = AppLanguage.selected
        let formatter = DateFormatter()
        formatter.dateFormat = dateFormat.value
        formatter.locale = appLanguage.locale
        return formatter.string(from: self).capitalizingFirstLetter
    }
    
    func isEqual(with targetDate: Date) -> Bool {
        Calendar.current.isDate(self, inSameDayAs: targetDate)
    }

    func isFutureDay() -> Bool {
        Calendar.current.startOfDay(for: self) > Calendar.current.startOfDay(for: Date())
    }
    
    func isInSameMonth(as date: Date) -> Bool {
        Calendar.current.isDate(self, equalTo: date, toGranularity: .month)
    }
    
    /// This funtion to check if Date this define month or note
    /// - Parameter month: month to compare
    /// - Returns: is equal or not
    func isMonth(_ month: Int) -> Bool {
        Calendar.current.component(.month, from: self) == month
    }
    
    var startOfMonth: Date {
        Calendar.current.date(
            from: Calendar.current.dateComponents([.year, .month], from: self)
        )!
    }
    
    func generateMonthsTo(to end: Date) -> [Date] {
        var months: [Date] = []
        var current = end.startOfMonth
        
        while current >= self.startOfMonth {
            months.append(current)
            
            current = Calendar.current.date(
                byAdding: .month,
                value: -1,
                to: current
            )!
        }
        
        return months
    }
    
    func generateMonthsFrom(to start: Date) -> [Date] {
        var months: [Date] = []
        var current = self.startOfMonth
        
        while current >= start.startOfMonth {
            months.append(current)
            
            current = Calendar.current.date(
                byAdding: .month,
                value: -1,
                to: current
            )!
        }
        
        return months
    }
}
