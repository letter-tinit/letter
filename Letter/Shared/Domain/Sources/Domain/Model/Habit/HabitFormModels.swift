import Foundation
import Utility

public enum HabitFormMode: Equatable {
    case create
    case edit(UUID)
    case newVersion(UUID)
}

public struct HabitDraft {
    public let name: String
    public let description: String
    public let icon: String
    public let colorHex: String
    public let startDate: Date
    public let endDate: Date?
    public let frequency: HabitFrequency
    public let targetDaysOfWeek: [Int]
    public let goalType: GoalType
    public let goalCount: Int
    public let goalUnit: String
    public let reminders: [HabitReminderConfiguration]
    public init(name: String, description: String, icon: String, colorHex: String, startDate: Date, endDate: Date?, frequency: HabitFrequency, targetDaysOfWeek: [Int], goalType: GoalType, goalCount: Int, goalUnit: String, reminders: [HabitReminderConfiguration]) { self.name=name; self.description=description; self.icon=icon; self.colorHex=colorHex; self.startDate=startDate; self.endDate=endDate; self.frequency=frequency; self.targetDaysOfWeek=targetDaysOfWeek; self.goalType=goalType; self.goalCount=goalCount; self.goalUnit=goalUnit; self.reminders=reminders }
}

public struct HabitStreakValues {
    public let current: Int
    public let longest: Int
    public let lastCompletedDate: Date?
}

public enum HabitFormError: Error {
    case habitNotFound
    case persistenceFailed(Error)
}
