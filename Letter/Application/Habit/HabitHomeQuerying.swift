import Foundation

@MainActor
protocol HabitHomeQuerying {
    func habitItems(
        on date: Date,
        relativeTo today: Date,
        calendar: Calendar
    ) throws -> [HabitListItem]
    func dayProgress(for dates: [Date], calendar: Calendar) throws -> [HabitDayProgress]
}

/// Read-only application boundary for the Habit home screen.
///
/// The use case owns orchestration. Its data dependency only returns plain
/// values, so neither the presentation nor domain layers receive SwiftData
/// records.
@MainActor
struct HabitHomeQuery: HabitHomeQuerying {
    private let snapshots: any HabitSnapshotReading
    private let policy: HabitListPolicy

    init(snapshots: any HabitSnapshotReading) {
        self.snapshots = snapshots
        policy = HabitListPolicy()
    }

    func habitItems(
        on date: Date,
        relativeTo today: Date,
        calendar: Calendar
    ) throws -> [HabitListItem] {
        policy.habits(
            from: try snapshots.fetchHabitSnapshots(),
            scheduledOn: date,
            relativeTo: today,
            calendar: calendar
        )
    }

    func dayProgress(for dates: [Date], calendar: Calendar) throws -> [HabitDayProgress] {
        policy.dayProgress(
            for: dates,
            habits: try snapshots.fetchHabitSnapshots(),
            calendar: calendar
        )
    }
}
