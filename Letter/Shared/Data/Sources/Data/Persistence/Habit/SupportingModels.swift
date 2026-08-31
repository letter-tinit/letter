import Foundation
import SwiftData
import Domain
import Core
import Utility

// MARK: - HabitReminder SwiftData Record
// Supports multiple custom reminder times per habit.

@Model
public final class HabitReminder {
    public var id: UUID
    public var time: Date            // Only time component is used
    public var daysOfWeek: [Int]     // Empty = every scheduled day
    public var isEnabled: Bool
    public var notificationID: String  // Maps to UNNotificationRequest identifier

    public var habit: Habit?

    public init(time: Date, daysOfWeek: [Int] = [], isEnabled: Bool = true) {
        self.id = UUID()
        self.time = time
        self.daysOfWeek = daysOfWeek
        self.isEnabled = isEnabled
        self.notificationID = UUID().uuidString
    }
}

// MARK: - UserProfile
// Singleton-style; stores app-wide settings and aggregated stats.

@Model
public final class UserProfile {
    public var id: UUID
    public var displayName: String
    public var avatarOriginalData: Data?   // Source image used for future edits
    public var avatarData: Data?           // Cropped/rendered image used for display

    // App preferences
    public var weekStartsOnMonday: Bool
    public var usesSimplifiedStatisticsMode: Bool = false
    public var defaultReminderTime: Date?
    public var colorSchemeRawValue: String = AppColorScheme.light.rawValue
    public var themeColorHex: String

    // Aggregated lifetime stats (updated on each completion)
    public var totalCompletions: Int
    public var totalHabitsCreated: Int
    public var longestOverallStreak: Int
    public var joinedAt: Date

    public init(displayName: String = "You") {
        self.id = UUID()
        self.displayName = displayName
        self.weekStartsOnMonday = true
        self.usesSimplifiedStatisticsMode = false
        self.colorSchemeRawValue = AppColorScheme.light.rawValue
        self.themeColorHex = "#4ECDC4"
        self.totalCompletions = 0
        self.totalHabitsCreated = 0
        self.longestOverallStreak = 0
        self.joinedAt = Date()
    }

    public var colorScheme: AppColorScheme {
        get {
            AppColorScheme(rawValue: colorSchemeRawValue) ?? .light
        }
        set {
            colorSchemeRawValue = newValue.rawValue
        }
    }
}
