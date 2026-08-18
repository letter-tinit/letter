//
//  Calendar+Extension.swift
//  Personal Finance
//
//  Created by TiniT on 16/7/26.
//

import Foundation

extension Calendar {
    func startOfMonth(for date: Date) -> Date {
        let components = dateComponents([.year, .month], from: date)
        return self.date(from: components) ?? startOfDay(for: date)
    }
    
    func nextMonth(after date: Date) -> Date {
        self.date(
            byAdding: .month,
            value: 1,
            to: startOfMonth(for: date)
        ) ?? startOfMonth(for: date)
    }
    
    var currentYear: Int {
        component(.year, from: .now)
    }
}
