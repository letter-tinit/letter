import Foundation
import SwiftData

// MARK: - HabitReminder
// Supports multiple custom reminder times per habit.

@Model
final class HabitReminder {
    var id: UUID
    var time: Date            // Only time component is used
    var daysOfWeek: [Int]     // Empty = every scheduled day
    var isEnabled: Bool
    var notificationID: String  // Maps to UNNotificationRequest identifier

    var habit: Habit?

    init(time: Date, daysOfWeek: [Int] = [], isEnabled: Bool = true) {
        self.id = UUID()
        self.time = time
        self.daysOfWeek = daysOfWeek
        self.isEnabled = isEnabled
        self.notificationID = UUID().uuidString
    }
}

struct HabitReminderConfiguration: Identifiable {
    let id: UUID
    var time: Date
    var daysOfWeek: [Int]
    var isEnabled: Bool

    init(
        id: UUID = UUID(),
        time: Date,
        daysOfWeek: [Int] = [],
        isEnabled: Bool = true
    ) {
        self.id = id
        self.time = time
        self.daysOfWeek = daysOfWeek
        self.isEnabled = isEnabled
    }

    init(_ reminder: HabitReminder) {
        self.id = reminder.id
        self.time = reminder.time
        self.daysOfWeek = reminder.daysOfWeek
        self.isEnabled = reminder.isEnabled
    }
}

enum AppColorScheme: String, Codable, CaseIterable, Identifiable {
    case system
    case light
    case dark

    var id: String {
        rawValue
    }

    var title: String {
        switch self {
        case .system:
            "System"
        case .light:
            "Light"
        case .dark:
            "Dark"
        }
    }
}

// MARK: - UserProfile
// Singleton-style; stores app-wide settings and aggregated stats.

@Model
final class UserProfile {
    var id: UUID
    var displayName: String
    var avatarOriginalData: Data?   // Source image used for future edits
    var avatarData: Data?           // Cropped/rendered image used for display

    // App preferences
    var weekStartsOnMonday: Bool
    var usesSimplifiedStatisticsMode: Bool = false
    var defaultReminderTime: Date?
    var colorSchemeRawValue: String = AppColorScheme.system.rawValue
    var themeColorHex: String

    // Aggregated lifetime stats (updated on each completion)
    var totalCompletions: Int
    var totalHabitsCreated: Int
    var longestOverallStreak: Int
    var joinedAt: Date

    init(displayName: String = "You") {
        self.id = UUID()
        self.displayName = displayName
        self.weekStartsOnMonday = true
        self.usesSimplifiedStatisticsMode = false
        self.colorSchemeRawValue = AppColorScheme.system.rawValue
        self.themeColorHex = "#4ECDC4"
        self.totalCompletions = 0
        self.totalHabitsCreated = 0
        self.longestOverallStreak = 0
        self.joinedAt = Date()
    }

    var colorScheme: AppColorScheme {
        get {
            AppColorScheme(rawValue: colorSchemeRawValue) ?? .system
        }
        set {
            colorSchemeRawValue = newValue.rawValue
        }
    }
}
