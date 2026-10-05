//
//  HabitDetailDependency.swift
//  Presentation
//
//  Created by Tín Nguyễn on 5/10/26.
//

import Foundation

public struct HabitDetailDependency: Hashable {
    public let habitID: UUID
    public let selectedDate: Date
    
    public init(habitID: UUID, selectedDate: Date) {
        self.habitID = habitID
        self.selectedDate = selectedDate
    }
}
