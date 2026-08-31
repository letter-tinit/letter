import Foundation
import Domain
import Utility

public enum HabitBackupError: LocalizedError {
    case unsupportedSchemaVersion(Int)
    case invalidData(String)
    case saveFailed

    public var errorDescription: String? {
        switch self {
        case .unsupportedSchemaVersion(let version):
            "habit.backup.error.unsupportedVersion".localized(version)
        case .invalidData(let message):
            message
        case .saveFailed:
            "habit.backup.error.save".localized
        }
    }
}

public struct HabitBackup: Codable {
    public static let currentSchemaVersion = 1

    public var schemaVersion: Int
    public var exportedAt: Date
    public var profile: UserProfileBackup?
    public var habits: [HabitBackupItem]

    public init(profile: UserProfile?, habits: [Habit]) {
        self.schemaVersion = Self.currentSchemaVersion
        self.exportedAt = Date()
        self.profile = profile.map(UserProfileBackup.init)
        self.habits = habits.map(HabitBackupItem.init)
    }
}

public extension HabitBackup {
    public func validate() throws {
        guard schemaVersion == Self.currentSchemaVersion else {
            throw HabitBackupError.unsupportedSchemaVersion(schemaVersion)
        }

        let habitIDs = habits.map(\.id)
        guard Set(habitIDs).count == habitIDs.count else {
            throw HabitBackupError.invalidData("habit.backup.error.duplicateHabits".localized)
        }

        for habit in habits {
            try habit.validate()
        }
    }
}

public extension HabitBackupItem {
    public func validate() throws {
        guard !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw HabitBackupError.invalidData("habit.backup.error.emptyName".localized)
        }

        guard goalCount > 0 else {
            throw HabitBackupError.invalidData("habit.backup.error.invalidGoal".localized(name))
        }

        guard targetDaysOfWeek.allSatisfy({ (0...6).contains($0) }) else {
            throw HabitBackupError.invalidData("habit.backup.error.invalidSchedule".localized(name))
        }

        if let versionNumber {
            guard versionNumber > 0 else {
                throw HabitBackupError.invalidData("habit.backup.error.invalidVersion".localized(name))
            }
        }

        if replacedHabitID == id {
            throw HabitBackupError.invalidData("habit.backup.error.selfReplacement".localized(name))
        }

        if let endDate {
            let calendar = AppCalendar.current
            let startDay = calendar.startOfDay(for: effectiveStartDate)
            let endDay = calendar.startOfDay(for: endDate)

            guard endDay >= startDay else {
                throw HabitBackupError.invalidData("habit.backup.error.invalidDates".localized(name))
            }
        }

        let entryIDs = entries.map(\.id)
        guard Set(entryIDs).count == entryIDs.count else {
            throw HabitBackupError.invalidData("habit.backup.error.duplicateEntries".localized(name))
        }

        let reminderIDs = reminders.map(\.id)
        guard Set(reminderIDs).count == reminderIDs.count else {
            throw HabitBackupError.invalidData("habit.backup.error.duplicateReminders".localized(name))
        }

        for entry in entries {
            try entry.validate(habitName: name)
        }

        for reminder in reminders {
            try reminder.validate(habitName: name)
        }
    }
}

public extension HabitEntryBackupItem {
    public func validate(habitName: String) throws {
        guard completedCount >= 0 else {
            throw HabitBackupError.invalidData("habit.backup.error.negativeEntry".localized(habitName))
        }

        if status == .skipped && completedCount != 0 {
            throw HabitBackupError.invalidData("habit.backup.error.skippedProgress".localized(habitName))
        }
    }
}

public extension HabitReminderBackupItem {
    public func validate(habitName: String) throws {
        guard daysOfWeek.allSatisfy({ (0...6).contains($0) }) else {
            throw HabitBackupError.invalidData("habit.backup.error.invalidReminderDays".localized(habitName))
        }

        guard !notificationID.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw HabitBackupError.invalidData("habit.backup.error.emptyNotificationID".localized(habitName))
        }
    }
}

nonisolated
public struct UserProfileBackup: Codable {
    public var id: UUID
    public var displayName: String
    public var avatarOriginalData: Data?
    public var avatarData: Data?
    public var weekStartsOnMonday: Bool
    public var usesSimplifiedStatisticsMode: Bool
    public var defaultReminderTime: Date?
    public var colorScheme: AppColorScheme
    public var themeColorHex: String
    public var totalCompletions: Int
    public var totalHabitsCreated: Int
    public var longestOverallStreak: Int
    public var joinedAt: Date

    public init(_ profile: UserProfile) {
        id = profile.id
        displayName = profile.displayName
        avatarOriginalData = profile.avatarOriginalData
        avatarData = profile.avatarData
        weekStartsOnMonday = profile.weekStartsOnMonday
        usesSimplifiedStatisticsMode = profile.usesSimplifiedStatisticsMode
        defaultReminderTime = profile.defaultReminderTime
        colorScheme = profile.colorScheme
        themeColorHex = profile.themeColorHex
        totalCompletions = profile.totalCompletions
        totalHabitsCreated = profile.totalHabitsCreated
        longestOverallStreak = profile.longestOverallStreak
        joinedAt = profile.joinedAt
    }

    enum CodingKeys: String, CodingKey {
        case id
        case displayName
        case avatarOriginalData
        case avatarData
        case weekStartsOnMonday
        case usesSimplifiedStatisticsMode
        case defaultReminderTime
        case colorScheme
        case themeColorHex
        case totalCompletions
        case totalHabitsCreated
        case longestOverallStreak
        case joinedAt
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        displayName = try container.decode(String.self, forKey: .displayName)
        avatarOriginalData = try container.decodeIfPresent(Data.self, forKey: .avatarOriginalData)
        avatarData = try container.decodeIfPresent(Data.self, forKey: .avatarData)
        weekStartsOnMonday = try container.decode(Bool.self, forKey: .weekStartsOnMonday)
        usesSimplifiedStatisticsMode = try container.decode(Bool.self, forKey: .usesSimplifiedStatisticsMode)
        defaultReminderTime = try container.decodeIfPresent(Date.self, forKey: .defaultReminderTime)
        let colorSchemeRawValue = try container.decodeIfPresent(String.self, forKey: .colorScheme)
        colorScheme = AppColorScheme(rawValue: colorSchemeRawValue ?? "") ?? .light
        themeColorHex = try container.decode(String.self, forKey: .themeColorHex)
        totalCompletions = try container.decode(Int.self, forKey: .totalCompletions)
        totalHabitsCreated = try container.decode(Int.self, forKey: .totalHabitsCreated)
        longestOverallStreak = try container.decode(Int.self, forKey: .longestOverallStreak)
        joinedAt = try container.decode(Date.self, forKey: .joinedAt)
    }
}

nonisolated
public struct HabitBackupItem: Codable {
    public var id: UUID
    public var name: String
    public var habitDescription: String
    public var icon: String
    public var colorHex: String
    public var createdAt: Date
    public var archivedAt: Date?
    public var sortOrder: Int
    public var seriesID: UUID?
    public var replacedHabitID: UUID?
    public var versionNumber: Int?
    public var startDate: Date?
    public var endDate: Date?
    public var frequency: HabitFrequency
    public var targetDaysOfWeek: [Int]
    public var reminderTime: Date?
    public var goalType: GoalType
    public var goalCount: Int
    public var goalUnit: String
    public var currentStreak: Int
    public var longestStreak: Int
    public var lastCompletedDate: Date?
    public var entries: [HabitEntryBackupItem]
    public var reminders: [HabitReminderBackupItem]

    public init(_ habit: Habit) {
        id = habit.id
        name = habit.name
        habitDescription = habit.habitDescription
        icon = habit.icon
        colorHex = habit.colorHex
        createdAt = habit.createdAt
        archivedAt = habit.archivedAt
        sortOrder = habit.sortOrder
        seriesID = habit.effectiveSeriesID
        replacedHabitID = habit.replacedHabitID
        versionNumber = habit.displayVersionNumber
        startDate = habit.effectiveStartDate
        endDate = habit.endDate
        frequency = habit.frequency
        targetDaysOfWeek = habit.targetDaysOfWeek
        reminderTime = habit.reminderTime
        goalType = habit.goalType
        goalCount = habit.goalCount
        goalUnit = habit.goalUnit
        currentStreak = habit.currentStreak
        longestStreak = habit.longestStreak
        lastCompletedDate = habit.lastCompletedDate
        entries = habit.entries.map(HabitEntryBackupItem.init)
        reminders = habit.reminders.map(HabitReminderBackupItem.init)
    }

    enum CodingKeys: String, CodingKey {
        case id
        case name
        case habitDescription
        case icon
        case colorHex
        case createdAt
        case archivedAt
        case sortOrder
        case seriesID
        case replacedHabitID
        case versionNumber
        case startDate
        case endDate
        case frequency
        case targetDaysOfWeek
        case reminderTime
        case goalType
        case goalCount
        case goalUnit
        case currentStreak
        case longestStreak
        case lastCompletedDate
        case entries
        case reminders
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        id = try container.decode(UUID.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        habitDescription = try container.decode(String.self, forKey: .habitDescription)
        icon = try container.decode(String.self, forKey: .icon)
        colorHex = try container.decode(String.self, forKey: .colorHex)
        createdAt = try container.decode(Date.self, forKey: .createdAt)
        archivedAt = try container.decodeIfPresent(Date.self, forKey: .archivedAt)
        sortOrder = try container.decodeIfPresent(Int.self, forKey: .sortOrder) ?? 0
        seriesID = try container.decodeIfPresent(UUID.self, forKey: .seriesID)
        replacedHabitID = try container.decodeIfPresent(UUID.self, forKey: .replacedHabitID)
        versionNumber = try container.decodeIfPresent(Int.self, forKey: .versionNumber)
        startDate = try container.decodeIfPresent(Date.self, forKey: .startDate)
        endDate = try container.decodeIfPresent(Date.self, forKey: .endDate)
        frequency = try container.decode(HabitFrequency.self, forKey: .frequency)
        targetDaysOfWeek = try container.decode([Int].self, forKey: .targetDaysOfWeek)
        reminderTime = try container.decodeIfPresent(Date.self, forKey: .reminderTime)
        goalType = try container.decode(GoalType.self, forKey: .goalType)
        goalCount = try container.decode(Int.self, forKey: .goalCount)
        goalUnit = try container.decode(String.self, forKey: .goalUnit)
        currentStreak = try container.decode(Int.self, forKey: .currentStreak)
        longestStreak = try container.decode(Int.self, forKey: .longestStreak)
        lastCompletedDate = try container.decodeIfPresent(Date.self, forKey: .lastCompletedDate)
        entries = try container.decode([HabitEntryBackupItem].self, forKey: .entries)
        reminders = try container.decode([HabitReminderBackupItem].self, forKey: .reminders)
    }

    public var effectiveStartDate: Date {
        startDate ?? createdAt
    }
}

nonisolated
public struct HabitEntryBackupItem: Codable {
    public var id: UUID
    public var date: Date
    public var completedCount: Int
    public var status: HabitEntryStatus
    public var note: String
    public var mood: MoodRating?
    public var createdAt: Date
    public var updatedAt: Date

    public init(_ entry: HabitEntry) {
        id = entry.id
        date = entry.date
        completedCount = entry.completedCount
        status = entry.status
        note = entry.note
        mood = entry.mood
        createdAt = entry.createdAt
        updatedAt = entry.updatedAt
    }

    enum CodingKeys: String, CodingKey {
        case id
        case date
        case completedCount
        case status
        case note
        case mood
        case createdAt
        case updatedAt
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        id = try container.decode(UUID.self, forKey: .id)
        date = try container.decode(Date.self, forKey: .date)
        completedCount = try container.decode(Int.self, forKey: .completedCount)
        status = try container.decodeIfPresent(HabitEntryStatus.self, forKey: .status) ?? .active
        note = try container.decode(String.self, forKey: .note)
        mood = try container.decodeIfPresent(MoodRating.self, forKey: .mood)
        createdAt = try container.decode(Date.self, forKey: .createdAt)
        updatedAt = try container.decode(Date.self, forKey: .updatedAt)
    }
}

nonisolated
public struct HabitReminderBackupItem: Codable {
    public var id: UUID
    public var time: Date
    public var daysOfWeek: [Int]
    public var isEnabled: Bool
    public var notificationID: String

    public init(_ reminder: HabitReminder) {
        id = reminder.id
        time = reminder.time
        daysOfWeek = reminder.daysOfWeek
        isEnabled = reminder.isEnabled
        notificationID = reminder.notificationID
    }
}
