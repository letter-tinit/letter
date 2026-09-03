import Foundation
import SwiftData
import Domain
import Utility

// MARK: - Habit SwiftData Record

@Model
public final class Habit: Hashable {
    public var id: UUID
    public var name: String
    public var habitDescription: String
    public var icon: String           // SF Symbol name, e.g. "drop.fill"
    public var colorHex: String       // e.g. "#FF6B6B"
    public var createdAt: Date
    public var archivedAt: Date?      // nil = active
    public var sortOrder: Int = 0
    public var seriesID: UUID?        // Shared by all versions of the same habit
    public var replacedHabitID: UUID? // Previous habit version, if this habit continues one
    public var versionNumber: Int?    // nil for older data; treated as version 1

    // Scheduling
    public var startDate: Date?                    // nil falls back to createdAt for older data
    public var endDate: Date?                      // nil = forever
    public var frequency: HabitFrequency          // daily / weekly / custom
    public var targetDaysOfWeek: [Int]            // 0=Sun … 6=Sat (used when frequency == .weekly/.custom)
    public var reminderTime: Date?                // optional daily reminder

    // Goal
    public var goalType: GoalType                 // boolean (done/not done) or count-based
    public var goalCount: Int                     // target count per period (1 for boolean habits)
    public var goalUnit: String                   // e.g. "glasses", "pages", "minutes"

    // Streaks (denormalised for fast reads)
    public var currentStreak: Int
    public var longestStreak: Int
    public var lastCompletedDate: Date?

    // Relationships
    @Relationship(deleteRule: .cascade, inverse: \HabitEntry.habit)
    public var entries: [HabitEntry]

    @Relationship(deleteRule: .cascade, inverse: \HabitReminder.habit)
    public var reminders: [HabitReminder]

    // MARK: - Init
    public init(
        name: String,
        description: String = "",
        icon: String = "star.fill",
        colorHex: String = "#4ECDC4",
        startDate: Date? = nil,
        endDate: Date? = nil,
        frequency: HabitFrequency = .daily,
        targetDaysOfWeek: [Int] = [],
        goalType: GoalType = .todo,
        goalCount: Int = 1,
        goalUnit: String = "times",
        seriesID: UUID? = nil,
        replacedHabitID: UUID? = nil,
        versionNumber: Int = 1
    ) {
        let habitID = UUID()

        self.id = habitID
        self.name = name
        self.habitDescription = description
        self.icon = icon
        self.colorHex = colorHex
        self.createdAt = Date()
        self.sortOrder = Int(Date().timeIntervalSince1970)
        self.seriesID = seriesID ?? habitID
        self.replacedHabitID = replacedHabitID
        self.versionNumber = max(versionNumber, 1)
        self.startDate = startDate
        self.endDate = endDate
        self.frequency = frequency
        self.targetDaysOfWeek = targetDaysOfWeek
        self.goalType = goalType
        self.goalCount = goalCount
        self.goalUnit = goalUnit
        self.currentStreak = 0
        self.longestStreak = 0
        self.entries = []
        self.reminders = []
    }
}

extension Habit {
    public var isArchived: Bool {
        archivedAt != nil
    }

    public var effectiveStartDate: Date {
        startDate ?? createdAt
    }

    public var effectiveSeriesID: UUID {
        seriesID ?? id
    }

    public var displayVersionNumber: Int {
        max(versionNumber ?? 1, 1)
    }

    public var isVersioned: Bool {
        displayVersionNumber > 1 || replacedHabitID != nil
    }

    public func entry(for date: Date) -> HabitEntry? {
        let targetDate = AppCalendar.current.startOfDay(for: date)

        return entries.first {
            $0.date.isEqual(with: targetDate)
        }
    }
}
