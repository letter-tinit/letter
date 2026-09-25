import Foundation
import Utility

/// Domain-facing persistence contract for the Habits feature.
/// It describes Habit operations and does not expose SwiftData primitives.
@MainActor
public protocol HabitRepository: AnyObject {
    func fetchHabitSnapshots() throws -> [HabitSnapshot]
    func fetchUserProfile() throws -> UserProfileSnapshot?
    func createDefaultUserProfile() throws -> UserProfileSnapshot
    func updateProfileWeekStart(_ enabled: Bool) throws -> UserProfileSnapshot?
    func updateProfileColorScheme(_ colorScheme: AppColorScheme) throws -> UserProfileSnapshot?
    func updateProfile(
        displayName: String,
        avatarOriginalData: Data?,
        avatarData: Data?
    ) throws -> UserProfileSnapshot?
    func fetchUsesCompactStatisticsView() throws -> Bool
    func setUsesCompactStatisticsView(_ enabled: Bool) throws

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
    func deleteHabit(id: UUID) throws -> Bool
    func persistEntry(
        _ values: HabitEntryValues,
        habitID: UUID,
        streak: HabitStreakValues
    ) throws -> HabitSnapshot?

}
