import Foundation

// Temporary compatibility for legacy policies that still consume SwiftData
// records. New policies should consume HabitSnapshot instead.
extension Habit: HabitScheduling {}
