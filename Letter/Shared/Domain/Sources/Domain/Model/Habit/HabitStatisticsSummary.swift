//
//  HabitStatisticsSummary.swift
//  Letter
//
//  Created by Tín Nguyễn on 18/8/26.
//

import Foundation
import Utility

public struct HabitStatisticSummary {
    public let progress: Double
    public let scheduledDays: Int
    public let completedDays: Int
    public let skippedDays: Int
    public let totalCompletedCount: Int
    public let totalTargetCount: Int
}

public struct WeekDaySummary {
    public let date: Date
    public let isSelected: Bool
    public let isToday: Bool
    public let isComplete: Bool
    public let completionRatio: Double
    public init(date: Date, isSelected: Bool, isToday: Bool, isComplete: Bool, completionRatio: Double) { self.date=date; self.isSelected=isSelected; self.isToday=isToday; self.isComplete=isComplete; self.completionRatio=completionRatio }
}

public struct HabitDayProgress {
    public let date: Date
    public let isComplete: Bool
    public let completionRatio: Double
}

public struct HabitDayStatistic {
    public let isScheduled: Bool
    public let isSkipped: Bool
    public let progress: Double
}
