import Foundation
import Utility

/// Domain output for one habit scheduled on a requested day.
public struct HabitListItem: Identifiable {
    public let id: UUID
    public let name: String
    public let icon: String
    public let colorHex: String
    public let goalType: GoalType
    public let goalCount: Int
    public let goalUnit: String
    public let completedCount: Int
    public let completionRatio: Double
    public let isSkipped: Bool
    public let currentStreak: Int
    public let longestStreak: Int
    public let lastCompletedDate: Date?
    public let canEditEntry: Bool
    public let canResetEntry: Bool
    public let entryIsCompleted: Bool
    public init(id: UUID, name: String, icon: String, colorHex: String, goalType: GoalType, goalCount: Int, goalUnit: String, completedCount: Int, completionRatio: Double, isSkipped: Bool, currentStreak: Int, longestStreak: Int, lastCompletedDate: Date?, canEditEntry: Bool, canResetEntry: Bool, entryIsCompleted: Bool) { self.id=id; self.name=name; self.icon=icon; self.colorHex=colorHex; self.goalType=goalType; self.goalCount=goalCount; self.goalUnit=goalUnit; self.completedCount=completedCount; self.completionRatio=completionRatio; self.isSkipped=isSkipped; self.currentStreak=currentStreak; self.longestStreak=longestStreak; self.lastCompletedDate=lastCompletedDate; self.canEditEntry=canEditEntry; self.canResetEntry=canResetEntry; self.entryIsCompleted=entryIsCompleted }
}
