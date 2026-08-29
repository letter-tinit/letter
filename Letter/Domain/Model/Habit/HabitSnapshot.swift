import Foundation

protocol HabitScheduling {
    var effectiveStartDate: Date { get }
    var endDate: Date? { get }
    var archivedAt: Date? { get }
    var frequency: HabitFrequency { get }
    var targetDaysOfWeek: [Int] { get }
}

/// Framework-independent representation of the Habit aggregate.
///
/// Data adapters create this value while their persistence records are still
/// attached. Inner layers can then evaluate rules without retaining SwiftData
/// objects or resolving faults from a view.
struct HabitSnapshot: HabitScheduling {
    let id: UUID
    let name: String
    let icon: String
    let colorHex: String
    let createdAt: Date
    let archivedAt: Date?
    let sortOrder: Int
    let startDate: Date?
    let endDate: Date?
    let frequency: HabitFrequency
    let targetDaysOfWeek: [Int]
    let goalType: GoalType
    let goalCount: Int
    let goalUnit: String
    let currentStreak: Int
    let longestStreak: Int
    let lastCompletedDate: Date?
    let entries: [HabitEntrySnapshot]

    var effectiveStartDate: Date {
        startDate ?? createdAt
    }
}

struct HabitEntrySnapshot {
    let date: Date
    let completedCount: Int
    let status: HabitEntryStatus

    var isSkipped: Bool {
        status == .skipped
    }

    func isCompleted(goalCount: Int) -> Bool {
        !isSkipped && goalCount > 0 && completedCount >= goalCount
    }

    func completionRatio(goalCount: Int) -> Double {
        guard !isSkipped, goalCount > 0 else { return 0 }
        return min(Double(completedCount) / Double(goalCount), 1)
    }
}
