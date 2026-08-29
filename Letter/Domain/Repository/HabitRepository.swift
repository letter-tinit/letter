import Foundation

/// Domain-facing persistence contract for the Habits feature.
/// It describes Habit operations and does not expose SwiftData primitives.
@MainActor
protocol HabitRepository: AnyObject {
    func fetchHabits() throws -> [Habit]
    func fetchHabitSnapshots() throws -> [HabitSnapshot]
    func fetchUserProfile() throws -> UserProfile?

    func createHabit(
        from draft: HabitDraft,
        id: UUID,
        createdAt: Date,
        sortOrder: Int
    ) throws -> HabitSnapshot
    func updateHabit(
        id: UUID,
        from draft: HabitDraft,
        streak: HabitStreakValues
    ) throws -> HabitSnapshot?
    func createHabitVersion(
        replacing sourceID: UUID,
        from draft: HabitDraft,
        id: UUID,
        createdAt: Date,
        startDate: Date,
        sourceEndDate: Date,
        versionNumber: Int,
        streak: HabitStreakValues
    ) throws -> HabitSnapshot?
    func setHabitArchived(_ archived: Bool, id: UUID, at date: Date) throws -> HabitSnapshot?
    func deleteHabit(id: UUID, reconnectingTo replacementID: UUID?) throws -> Bool
    func deleteHabits(ids: Set<UUID>) throws

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
