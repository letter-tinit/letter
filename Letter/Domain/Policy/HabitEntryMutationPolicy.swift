import Foundation

enum HabitEntryMutation {
    case unchanged
    case rejected
    case updated
    case inserted(HabitEntry)
}

/// Domain state transitions for a habit entry.
///
/// This type mutates models but performs no persistence, notifications, cache
/// invalidation, or user feedback. Those effects belong to the caller.
struct HabitEntryMutationPolicy {
    private let schedule = HabitSchedule()

    func updateProgress(
        for habit: Habit,
        on date: Date,
        completedCount: Int,
        note: String?,
        calendar: Calendar,
        now: Date = Date()
    ) -> HabitEntryMutation {
        guard canEdit(date, calendar: calendar, now: now) else {
            return .rejected
        }

        let targetDate = calendar.startOfDay(for: date)
        if let entry = entry(for: habit, on: targetDate, calendar: calendar) {
            guard entry.completedCount != completedCount ||
                    entry.isSkipped ||
                    note != nil
            else {
                return .unchanged
            }

            entry.completedCount = completedCount
            entry.status = .active
            if let note {
                entry.note = note
            }
            entry.updatedAt = now
            return .updated
        }

        guard completedCount > 0 || note?.isEmpty == false else {
            return .unchanged
        }

        let entry = HabitEntry(
            date: targetDate,
            completedCount: completedCount,
            note: note ?? ""
        )
        entry.habit = habit
        habit.entries.append(entry)
        return .inserted(entry)
    }

    func skip(
        _ habit: Habit,
        on date: Date,
        calendar: Calendar,
        now: Date = Date()
    ) -> HabitEntryMutation {
        let targetDate = calendar.startOfDay(for: date)
        guard schedule.isScheduled(habit, on: targetDate, calendar: calendar) else {
            return .rejected
        }

        if let entry = entry(for: habit, on: targetDate, calendar: calendar) {
            guard !entry.isCompleted else {
                return .rejected
            }
            guard !entry.isSkipped || entry.completedCount != 0 else {
                return .unchanged
            }

            entry.completedCount = 0
            entry.status = .skipped
            entry.updatedAt = now
            return .updated
        }

        let entry = HabitEntry(date: targetDate, status: .skipped)
        entry.habit = habit
        habit.entries.append(entry)
        return .inserted(entry)
    }

    func reset(
        _ habit: Habit,
        on date: Date,
        calendar: Calendar,
        now: Date = Date()
    ) -> HabitEntryMutation {
        let targetDate = calendar.startOfDay(for: date)
        let entry = entry(for: habit, on: targetDate, calendar: calendar)

        guard canEdit(date, calendar: calendar, now: now) || entry?.isSkipped == true else {
            return .rejected
        }
        guard let entry,
              entry.completedCount != 0 || entry.isSkipped
        else {
            return .unchanged
        }

        entry.completedCount = 0
        entry.status = .active
        entry.updatedAt = now
        return .updated
    }
}

private extension HabitEntryMutationPolicy {
    func canEdit(_ date: Date, calendar: Calendar, now: Date) -> Bool {
        calendar.startOfDay(for: date) <= calendar.startOfDay(for: now)
    }

    func entry(for habit: Habit, on date: Date, calendar: Calendar) -> HabitEntry? {
        habit.entries.first {
            calendar.isDate($0.date, inSameDayAs: date)
        }
    }
}
