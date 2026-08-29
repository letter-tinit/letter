import Foundation

/// Application port implemented by the persistence adapter.
@MainActor
protocol HabitSnapshotReading: AnyObject {
    func fetchHabitSnapshots() throws -> [HabitSnapshot]
}
