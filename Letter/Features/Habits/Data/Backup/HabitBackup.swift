import Foundation
import SwiftUI
import UniformTypeIdentifiers

enum HabitBackupError: LocalizedError {
    case unsupportedSchemaVersion(Int)
    case invalidData(String)
    case saveFailed

    var errorDescription: String? {
        switch self {
        case .unsupportedSchemaVersion(let version):
            "This backup uses schema version \(version), which this app cannot import."
        case .invalidData(let message):
            message
        case .saveFailed:
            "The backup could not be saved after import."
        }
    }
}

struct HabitBackup: Codable {
    static let currentSchemaVersion = 1

    var schemaVersion: Int
    var exportedAt: Date
    var profile: UserProfileBackup?
    var habits: [HabitBackupItem]

    init(profile: UserProfile?, habits: [Habit]) {
        self.schemaVersion = Self.currentSchemaVersion
        self.exportedAt = Date()
        self.profile = profile.map(UserProfileBackup.init)
        self.habits = habits.map(HabitBackupItem.init)
    }
}

struct HabitBackupSummary {
    let exportedAt: Date
    let habitCount: Int
    let entryCount: Int
    let reminderCount: Int
    let profileName: String
}

extension HabitBackup {
    var summary: HabitBackupSummary {
        HabitBackupSummary(
            exportedAt: exportedAt,
            habitCount: habits.count,
            entryCount: habits.reduce(0) { $0 + $1.entries.count },
            reminderCount: habits.reduce(0) { $0 + $1.reminders.count },
            profileName: profile?.displayName ?? "You"
        )
    }

    func validate() throws {
        guard schemaVersion == Self.currentSchemaVersion else {
            throw HabitBackupError.unsupportedSchemaVersion(schemaVersion)
        }

        let habitIDs = habits.map(\.id)
        guard Set(habitIDs).count == habitIDs.count else {
            throw HabitBackupError.invalidData("The backup contains duplicate habit IDs.")
        }

        for habit in habits {
            try habit.validate()
        }
    }
}

extension HabitBackupItem {
    func validate() throws {
        guard !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw HabitBackupError.invalidData("The backup contains a habit with an empty name.")
        }

        guard goalCount > 0 else {
            throw HabitBackupError.invalidData("The habit \"\(name)\" has an invalid goal count.")
        }

        guard targetDaysOfWeek.allSatisfy({ (0...6).contains($0) }) else {
            throw HabitBackupError.invalidData("The habit \"\(name)\" has invalid scheduled days.")
        }

        if let versionNumber {
            guard versionNumber > 0 else {
                throw HabitBackupError.invalidData("The habit \"\(name)\" has an invalid version number.")
            }
        }

        if replacedHabitID == id {
            throw HabitBackupError.invalidData("The habit \"\(name)\" cannot replace itself.")
        }

        if let endDate {
            let calendar = AppCalendar.current
            let startDay = calendar.startOfDay(for: effectiveStartDate)
            let endDay = calendar.startOfDay(for: endDate)

            guard endDay >= startDay else {
                throw HabitBackupError.invalidData("The habit \"\(name)\" ends before it starts.")
            }
        }

        let entryIDs = entries.map(\.id)
        guard Set(entryIDs).count == entryIDs.count else {
            throw HabitBackupError.invalidData("The habit \"\(name)\" contains duplicate entry IDs.")
        }

        let reminderIDs = reminders.map(\.id)
        guard Set(reminderIDs).count == reminderIDs.count else {
            throw HabitBackupError.invalidData("The habit \"\(name)\" contains duplicate reminder IDs.")
        }

        for entry in entries {
            try entry.validate(habitName: name)
        }

        for reminder in reminders {
            try reminder.validate(habitName: name)
        }
    }
}

extension HabitEntryBackupItem {
    func validate(habitName: String) throws {
        guard completedCount >= 0 else {
            throw HabitBackupError.invalidData("The habit \"\(habitName)\" contains an entry with a negative completion count.")
        }

        if status == .skipped && completedCount != 0 {
            throw HabitBackupError.invalidData("The habit \"\(habitName)\" contains a skipped entry with completion progress.")
        }
    }
}

extension HabitReminderBackupItem {
    func validate(habitName: String) throws {
        guard daysOfWeek.allSatisfy({ (0...6).contains($0) }) else {
            throw HabitBackupError.invalidData("The habit \"\(habitName)\" contains a reminder with invalid days.")
        }

        guard !notificationID.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw HabitBackupError.invalidData("The habit \"\(habitName)\" contains a reminder with an empty notification ID.")
        }
    }
}

struct UserProfileBackup: Codable {
    var id: UUID
    var displayName: String
    var avatarOriginalData: Data?
    var avatarData: Data?
    var weekStartsOnMonday: Bool
    var usesSimplifiedStatisticsMode: Bool
    var defaultReminderTime: Date?
    var colorScheme: AppColorScheme
    var themeColorHex: String
    var totalCompletions: Int
    var totalHabitsCreated: Int
    var longestOverallStreak: Int
    var joinedAt: Date

    init(_ profile: UserProfile) {
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

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        displayName = try container.decode(String.self, forKey: .displayName)
        avatarOriginalData = try container.decodeIfPresent(Data.self, forKey: .avatarOriginalData)
        avatarData = try container.decodeIfPresent(Data.self, forKey: .avatarData)
        weekStartsOnMonday = try container.decode(Bool.self, forKey: .weekStartsOnMonday)
        usesSimplifiedStatisticsMode = try container.decode(Bool.self, forKey: .usesSimplifiedStatisticsMode)
        defaultReminderTime = try container.decodeIfPresent(Date.self, forKey: .defaultReminderTime)
        colorScheme = try container.decodeIfPresent(AppColorScheme.self, forKey: .colorScheme) ?? .system
        themeColorHex = try container.decode(String.self, forKey: .themeColorHex)
        totalCompletions = try container.decode(Int.self, forKey: .totalCompletions)
        totalHabitsCreated = try container.decode(Int.self, forKey: .totalHabitsCreated)
        longestOverallStreak = try container.decode(Int.self, forKey: .longestOverallStreak)
        joinedAt = try container.decode(Date.self, forKey: .joinedAt)
    }
}

struct HabitBackupItem: Codable {
    var id: UUID
    var name: String
    var habitDescription: String
    var icon: String
    var colorHex: String
    var createdAt: Date
    var archivedAt: Date?
    var sortOrder: Int
    var seriesID: UUID?
    var replacedHabitID: UUID?
    var versionNumber: Int?
    var startDate: Date?
    var endDate: Date?
    var frequency: HabitFrequency
    var targetDaysOfWeek: [Int]
    var reminderTime: Date?
    var goalType: GoalType
    var goalCount: Int
    var goalUnit: String
    var currentStreak: Int
    var longestStreak: Int
    var lastCompletedDate: Date?
    var entries: [HabitEntryBackupItem]
    var reminders: [HabitReminderBackupItem]

    init(_ habit: Habit) {
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

    init(from decoder: Decoder) throws {
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

    var effectiveStartDate: Date {
        startDate ?? createdAt
    }
}

struct HabitEntryBackupItem: Codable {
    var id: UUID
    var date: Date
    var completedCount: Int
    var status: HabitEntryStatus
    var note: String
    var mood: MoodRating?
    var createdAt: Date
    var updatedAt: Date

    init(_ entry: HabitEntry) {
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

    init(from decoder: Decoder) throws {
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

struct HabitReminderBackupItem: Codable {
    var id: UUID
    var time: Date
    var daysOfWeek: [Int]
    var isEnabled: Bool
    var notificationID: String

    init(_ reminder: HabitReminder) {
        id = reminder.id
        time = reminder.time
        daysOfWeek = reminder.daysOfWeek
        isEnabled = reminder.isEnabled
        notificationID = reminder.notificationID
    }
}

struct HabitBackupDocument: FileDocument {
    static var readableContentTypes: [UTType] { [.json] }

    var data: Data

    init(data: Data = Data()) {
        self.data = data
    }

    init(configuration: ReadConfiguration) throws {
        guard let data = configuration.file.regularFileContents else {
            throw CocoaError(.fileReadCorruptFile)
        }

        self.data = data
    }

    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        FileWrapper(regularFileWithContents: data)
    }
}
