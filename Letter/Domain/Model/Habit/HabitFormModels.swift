import Foundation

enum HabitFormMode: Equatable {
    case create
    case edit(UUID)
    case newVersion(UUID)
}

struct HabitDraft {
    let name: String
    let description: String
    let icon: String
    let colorHex: String
    let startDate: Date
    let endDate: Date?
    let frequency: HabitFrequency
    let targetDaysOfWeek: [Int]
    let goalType: GoalType
    let goalCount: Int
    let goalUnit: String
    let reminders: [HabitReminderConfiguration]
}

struct HabitStreakValues {
    let current: Int
    let longest: Int
    let lastCompletedDate: Date?
}

enum HabitFormError: Error {
    case habitNotFound
    case persistenceFailed(Error)
}
