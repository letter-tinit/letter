import Foundation

/// Domain output for one habit scheduled on a requested day.
struct HabitListItem: Identifiable {
    let id: UUID
    let name: String
    let icon: String
    let colorHex: String
    let goalType: GoalType
    let goalCount: Int
    let goalUnit: String
    let completedCount: Int
    let completionRatio: Double
    let isSkipped: Bool
    let currentStreak: Int
    let longestStreak: Int
    let lastCompletedDate: Date?
    let canEditEntry: Bool
    let canResetEntry: Bool
    let entryIsCompleted: Bool
}
