import Foundation
import SwiftData

// MARK: - HabitEntry (Daily Log)
// One record per habit per calendar day.

@Model
final class HabitEntry {
    var id: UUID
    var date: Date              // Normalised to midnight (start of day) for easy querying
    var completedCount: Int     // 0 = not done; ≥ goalCount = fully done
    var statusRawValue: String = HabitEntryStatus.active.rawValue
    var note: String            // Optional journal note for that day
    var mood: MoodRating?       // Optional mood tag
    var createdAt: Date
    var updatedAt: Date

    // Relationship back to the parent Habit
    var habit: Habit?

    // MARK: - Computed helpers (not persisted)
    var isCompleted: Bool {
        guard !isSkipped else { return false }
        guard let habit else { return false }
        return completedCount >= habit.goalCount
    }

    var isSkipped: Bool {
        status == .skipped
    }

    var status: HabitEntryStatus {
        get {
            HabitEntryStatus(rawValue: statusRawValue) ?? .active
        }
        set {
            statusRawValue = newValue.rawValue
        }
    }

    var completionRatio: Double {
        guard !isSkipped else { return 0 }
        guard let habit, habit.goalCount > 0 else { return 0 }
        return min(Double(completedCount) / Double(habit.goalCount), 1.0)
    }

    // MARK: - Init
    init(
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

extension HabitEntry {
    func entry(for date: Date, in entries: [HabitEntry]) -> HabitEntry? {
        let targetDate = AppCalendar.current.startOfDay(for: date)

        return entries.first {
            $0.date.isEqual(with: targetDate)
        }
    }
}

enum HabitEntryStatus: String, Codable {
    case active
    case skipped
}

// MARK: - MoodRating

enum MoodRating: Int, Codable, CaseIterable {
    case terrible = 1
    case bad      = 2
    case neutral  = 3
    case good     = 4
    case great    = 5

    var emoji: String {
        switch self {
        case .terrible: return "😞"
        case .bad:      return "😕"
        case .neutral:  return "😐"
        case .good:     return "🙂"
        case .great:    return "😄"
        }
    }
}
