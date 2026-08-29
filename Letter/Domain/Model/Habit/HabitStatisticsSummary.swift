//
//  HabitStatisticsSummary.swift
//  Letter
//
//  Created by Tín Nguyễn on 18/8/26.
//

import Foundation

struct HabitStatisticSummary {
    let progress: Double
    let scheduledDays: Int
    let completedDays: Int
    let skippedDays: Int
    let totalCompletedCount: Int
    let totalTargetCount: Int
}

struct WeekDaySummary {
    let date: Date
    let isSelected: Bool
    let isToday: Bool
    let isComplete: Bool
    let completionRatio: Double
}

struct HabitDayProgress {
    let date: Date
    let isComplete: Bool
    let completionRatio: Double
}

struct HabitDayStatistic {
    let isScheduled: Bool
    let isSkipped: Bool
    let progress: Double
}
