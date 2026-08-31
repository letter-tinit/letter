import Foundation
import Utility

public protocol HabitScheduling {
    var effectiveStartDate: Date { get }
    var endDate: Date? { get }
    var archivedAt: Date? { get }
    var frequency: HabitFrequency { get }
    var targetDaysOfWeek: [Int] { get }
}

/// A proposed schedule used to evaluate policies before persistence.
public struct HabitScheduleConfiguration: HabitScheduling {
    public let effectiveStartDate: Date
    public let endDate: Date?
    public let archivedAt: Date?
    public let frequency: HabitFrequency
    public let targetDaysOfWeek: [Int]
}

/// Framework-independent representation of the Habit aggregate.
///
/// Data adapters create this value while their persistence records are still
/// attached. Inner layers can then evaluate rules without retaining SwiftData
/// objects or resolving faults from a view.
public struct HabitSnapshot: HabitScheduling {
    public let id: UUID
    public let name: String
    public let habitDescription: String
    public let icon: String
    public let colorHex: String
    public let createdAt: Date
    public let archivedAt: Date?
    public let sortOrder: Int
    public let seriesID: UUID?
    public let replacedHabitID: UUID?
    public let versionNumber: Int?
    public let startDate: Date?
    public let endDate: Date?
    public let frequency: HabitFrequency
    public let targetDaysOfWeek: [Int]
    public let goalType: GoalType
    public let goalCount: Int
    public let goalUnit: String
    public let currentStreak: Int
    public let longestStreak: Int
    public let lastCompletedDate: Date?
    public let reminders: [HabitReminderConfiguration]
    public let entries: [HabitEntrySnapshot]
    public init(id: UUID, name: String, habitDescription: String, icon: String, colorHex: String, createdAt: Date, archivedAt: Date?, sortOrder: Int, seriesID: UUID?, replacedHabitID: UUID?, versionNumber: Int?, startDate: Date?, endDate: Date?, frequency: HabitFrequency, targetDaysOfWeek: [Int], goalType: GoalType, goalCount: Int, goalUnit: String, currentStreak: Int, longestStreak: Int, lastCompletedDate: Date?, reminders: [HabitReminderConfiguration], entries: [HabitEntrySnapshot]) { self.id=id; self.name=name; self.habitDescription=habitDescription; self.icon=icon; self.colorHex=colorHex; self.createdAt=createdAt; self.archivedAt=archivedAt; self.sortOrder=sortOrder; self.seriesID=seriesID; self.replacedHabitID=replacedHabitID; self.versionNumber=versionNumber; self.startDate=startDate; self.endDate=endDate; self.frequency=frequency; self.targetDaysOfWeek=targetDaysOfWeek; self.goalType=goalType; self.goalCount=goalCount; self.goalUnit=goalUnit; self.currentStreak=currentStreak; self.longestStreak=longestStreak; self.lastCompletedDate=lastCompletedDate; self.reminders=reminders; self.entries=entries }

    public var effectiveStartDate: Date {
        startDate ?? createdAt
    }

    public var effectiveSeriesID: UUID {
        seriesID ?? id
    }

    public var displayVersionNumber: Int {
        max(versionNumber ?? 1, 1)
    }

    public var isVersioned: Bool {
        displayVersionNumber > 1 || replacedHabitID != nil
    }

    public var isArchived: Bool {
        archivedAt != nil
    }
}

public struct HabitEntrySnapshot {
    public let date: Date
    public let completedCount: Int
    public let status: HabitEntryStatus
    public init(date: Date, completedCount: Int, status: HabitEntryStatus) { self.date = date; self.completedCount = completedCount; self.status = status }

    public var isSkipped: Bool {
        status == .skipped
    }

    public func isCompleted(goalCount: Int) -> Bool {
        !isSkipped && goalCount > 0 && completedCount >= goalCount
    }

    public func completionRatio(goalCount: Int) -> Double {
        guard !isSkipped, goalCount > 0 else { return 0 }
        return min(Double(completedCount) / Double(goalCount), 1)
    }
}
