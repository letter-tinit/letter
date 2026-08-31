import Foundation
import Utility

public struct HabitVersionPlan {
    public let newStartDate: Date
    public let sourceEndDate: Date
    public let versionNumber: Int
}

public protocol HabitVersionUseCase {
    func plan(
        replacing source: HabitSnapshot,
        in habits: [HabitSnapshot],
        proposedStartDate: Date,
        now: Date,
        calendar: Calendar
    ) -> HabitVersionPlan
}

/// Deterministic rules for closing one Habit version and starting the next.
public struct ImpHabitVersionUseCase: HabitVersionUseCase {
    public func plan(
        replacing source: HabitSnapshot,
        in habits: [HabitSnapshot],
        proposedStartDate: Date,
        now: Date,
        calendar: Calendar
    ) -> HabitVersionPlan {
        let today = calendar.startOfDay(for: now)
        let minimumStart = calendar.date(byAdding: .day, value: 1, to: today) ?? today
        let newStart = max(calendar.startOfDay(for: proposedStartDate), minimumStart)
        let sourceStart = calendar.startOfDay(for: source.effectiveStartDate)
        let dayBeforeNewStart = calendar.date(byAdding: .day, value: -1, to: newStart) ?? today
        let latestSourceEnd = max(dayBeforeNewStart, sourceStart)
        let sourceEnd = source.endDate.map {
            min(max(calendar.startOfDay(for: $0), sourceStart), latestSourceEnd)
        } ?? latestSourceEnd

        return HabitVersionPlan(
            newStartDate: newStart,
            sourceEndDate: sourceEnd,
            versionNumber: nextVersionNumber(after: source, in: habits)
        )
    }

    private func nextVersionNumber(
        after source: HabitSnapshot,
        in habits: [HabitSnapshot]
    ) -> Int {
        let highestVersion = habits
            .filter { $0.effectiveSeriesID == source.effectiveSeriesID }
            .map(\.displayVersionNumber)
            .max() ?? source.displayVersionNumber
        return highestVersion + 1
    }
}
