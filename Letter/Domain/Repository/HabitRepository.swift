import Foundation

/// Domain-facing persistence contract for the Habits feature.
/// It describes Habit operations and does not expose SwiftData primitives.
@MainActor
protocol HabitRepository: AnyObject {
    func fetchHabits() throws -> [Habit]
    func fetchUserProfile() throws -> UserProfile?

    func addHabit(_ habit: Habit)
    func removeHabit(_ habit: Habit)
    func addEntry(_ entry: HabitEntry)
    func addReminder(_ reminder: HabitReminder)
    func removeReminder(_ reminder: HabitReminder)
    func addProfile(_ profile: UserProfile)

    func removeAllHabitData() throws
    func save() throws
    func rollback()
}
