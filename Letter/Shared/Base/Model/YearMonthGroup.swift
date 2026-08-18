//
//  YearMonthGroup.swift
//  Letter
//
//  Created by TiniT on 23/7/26.
//

import Foundation

struct YearMonthKey: Hashable {
    let year: Int
    let month: Int
    let originalDate: Date
}


struct YearMonthGroup<Model>: Identifiable {
    let id = UUID()
    
    let year: Int
    let month: Int
    let originalDate: Date
    let items: [Model]
    
    var title: String {
        return originalDate.toString(withFormat: .monthAndYear)
    }
}
