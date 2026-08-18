//
//  Array+Extension.swift
//  Letter
//
//  Created by TiniT on 23/7/26.
//

import Foundation

extension Array {
    func groupedByYearMonth(
        dateProvider: (Element) -> Date,
        calendar: Calendar = .current
    ) -> [YearMonthGroup<Element>] {
        
        let groups = Dictionary(grouping: self) { item -> YearMonthKey in
            let date = dateProvider(item)
            
            
            return YearMonthKey(
                year: calendar.component(.year, from: date),
                month: calendar.component(.month, from: date),
                originalDate: date
            )
        }
        
        return groups
            .map { key, items in
                let date = dateProvider(items[0])
                
                return YearMonthGroup(
                    year: key.year,
                    month: key.month,
                    originalDate: date,
                    items: items
                )
            }
            .sorted {
                if $0.year != $1.year {
                    return $0.year > $1.year
                }
                
                return $0.month > $1.month
            }
    }
}
