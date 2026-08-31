import Foundation
import Utility

public enum HabitEntryMutation {
    case unchanged
    case rejected
    case upsert(HabitEntryValues)
}

public struct HabitEntryValues {
    public let date: Date
    public let completedCount: Int
    public let status: HabitEntryStatus
    public let note: String?
    public let updatedAt: Date
}

public protocol HabitEntryUseCase {
    func updateProgress(
        for habit: HabitSnapshot,
        on date: Date,
        completedCount: Int,
        note: String?,
        calendar: Calendar,
        now: Date
    ) -> HabitEntryMutation
    func skip(
        _ habit: HabitSnapshot,
        on date: Date,
        calendar: Calendar,
        now: Date
    ) -> HabitEntryMutation
    func reset(
        _ habit: HabitSnapshot,
        on date: Date,
        calendar: Calendar,
        now: Date
    ) -> HabitEntryMutation
}

/// Deterministic state transitions for value snapshots. Persistence is applied
/// later by the repository while its SwiftData records are still attached.
public struct ImpHabitEntryUseCase: HabitEntryUseCase {
    private let schedule = ImpHabitScheduleUseCase()

    public func updateProgress(
        for habit: HabitSnapshot,
        on date: Date,
        completedCount: Int,
        note: String?,
        calendar: Calendar,
        now: Date
    ) -> HabitEntryMutation {
        guard canEdit(date, calendar: calendar, now: now) else { return .rejected }

        let targetDate = calendar.startOfDay(for: date)
        if let entry = entry(for: habit, on: targetDate, calendar: calendar) {
            guard entry.completedCount != completedCount || entry.isSkipped || note != nil else {
                return .unchanged
            }
            return .upsert(HabitEntryValues(
                date: targetDate,
                completedCount: completedCount,
                status: .active,
                note: note,
                updatedAt: now
            ))
        }

        guard completedCount > 0 || note?.isEmpty == false else { return .unchanged }
        return .upsert(HabitEntryValues(
            date: targetDate,
            completedCount: completedCount,
            status: .active,
            note: note ?? "",
            updatedAt: now
        ))
    }

    public func skip(
        _ habit: HabitSnapshot,
        on date: Date,
        calendar: Calendar,
        now: Date
    ) -> HabitEntryMutation {
        let targetDate = calendar.startOfDay(for: date)
        guard schedule.isScheduled(habit, on: targetDate, calendar: calendar) else {
            return .rejected
        }

        if let entry = entry(for: habit, on: targetDate, calendar: calendar) {
            guard !entry.isCompleted(goalCount: habit.goalCount) else { return .rejected }
            guard !entry.isSkipped || entry.completedCount != 0 else { return .unchanged }
        }

        return .upsert(HabitEntryValues(
            date: targetDate,
            completedCount: 0,
            status: .skipped,
            note: nil,
            updatedAt: now
        ))
    }

    public func reset(
        _ habit: HabitSnapshot,
        on date: Date,
        calendar: Calendar,
        now: Date
    ) -> HabitEntryMutation {
        let targetDate = calendar.startOfDay(for: date)
        let entry = entry(for: habit, on: targetDate, calendar: calendar)
        guard canEdit(date, calendar: calendar, now: now) || entry?.isSkipped == true else {
            return .rejected
        }
        guard let entry, entry.completedCount != 0 || entry.isSkipped else { return .unchanged }

        return .upsert(HabitEntryValues(
            date: targetDate,
            completedCount: 0,
            status: .active,
            note: nil,
            updatedAt: now
        ))
    }
}

private extension ImpHabitEntryUseCase {
    public func canEdit(_ date: Date, calendar: Calendar, now: Date) -> Bool {
        calendar.startOfDay(for: date) <= calendar.startOfDay(for: now)
    }

    public func entry(
        for habit: HabitSnapshot,
        on date: Date,
        calendar: Calendar
    ) -> HabitEntrySnapshot? {
        habit.entries.first { calendar.isDate($0.date, inSameDayAs: date) }
    }
}
