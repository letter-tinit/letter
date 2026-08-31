import Foundation
import SwiftData
import Domain
import Utility

// MARK: - HabitEntry SwiftData Record
// One record per habit per calendar day.

@Model
public final class HabitEntry {
    public var id: UUID
    public var date: Date              // Normalised to midnight (start of day) for easy querying
    public var completedCount: Int     // 0 = not done; ≥ goalCount = fully done
    public var statusRawValue: String = HabitEntryStatus.active.rawValue
    public var note: String            // Optional journal note for that day
    public var mood: MoodRating?       // Optional mood tag
    public var createdAt: Date
    public var updatedAt: Date

    // Relationship back to the parent Habit
    public var habit: Habit?

    // MARK: - Computed helpers (not persisted)
    public var isCompleted: Bool {
        guard !isSkipped else { return false }
        guard let habit else { return false }
        return completedCount >= habit.goalCount
    }

    public var isSkipped: Bool {
        status == .skipped
    }

    public var status: HabitEntryStatus {
        get {
            HabitEntryStatus(rawValue: statusRawValue) ?? .active
        }
        set {
            statusRawValue = newValue.rawValue
        }
    }

    public var completionRatio: Double {
        guard !isSkipped else { return 0 }
        guard let habit, habit.goalCount > 0 else { return 0 }
        return min(Double(completedCount) / Double(habit.goalCount), 1.0)
    }

    // MARK: - Init
    public init(
        date: Date,
        completedCount: Int = 0,
        status: HabitEntryStatus = .active,
        note: String = ""
    ) {
        self.id = UUID()
        self.date = AppCalendar.current.startOfDay(for: date)
        self.completedCount = completedCount
        self.statusRawValue = status.rawValue
        self.note = note
        self.createdAt = Date()
        self.updatedAt = Date()
    }
}

public extension HabitEntry {
    public func entry(for date: Date, in entries: [HabitEntry]) -> HabitEntry? {
        let targetDate = AppCalendar.current.startOfDay(for: date)

        return entries.first {
            $0.date.isEqual(with: targetDate)
        }
    }
}

// MARK: - MoodRating

public enum MoodRating: Int, Codable, CaseIterable {
    case terrible = 1
    case bad      = 2
    case neutral  = 3
    case good     = 4
    case great    = 5

    public var emoji: String {
        switch self {
        case .terrible: return "😞"
        case .bad:      return "😕"
        case .neutral:  return "😐"
        case .good:     return "🙂"
        case .great:    return "😄"
        }
    }
}
