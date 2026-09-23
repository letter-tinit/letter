import Foundation
@testable import Domain

enum HabitTestSupport {
    static var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        return calendar
    }

    static func date(_ year: Int, _ month: Int, _ day: Int) -> Date {
        calendar.date(from: DateComponents(year: year, month: month, day: day))!
    }

    static func makeHabit(
        id: UUID = UUID(),
        name: String = "Read",
        createdAt: Date = date(2024, 1, 1),
        archivedAt: Date? = nil,
        sortOrder: Int = 0,
        seriesID: UUID? = nil,
        replacedHabitID: UUID? = nil,
        versionNumber: Int? = nil,
        startDate: Date? = date(2024, 1, 1),
        endDate: Date? = nil,
        frequency: HabitFrequency = .daily,
        targetDaysOfWeek: [Int] = [],
        goalCount: Int = 2,
        currentStreak: Int = 0,
        longestStreak: Int = 0,
        lastCompletedDate: Date? = nil,
        entries: [HabitEntrySnapshot] = []
    ) -> HabitSnapshot {
        HabitSnapshot(
            id: id,
            name: name,
            habitDescription: "",
            icon: "book",
            colorHex: "#00AA00",
            createdAt: createdAt,
            archivedAt: archivedAt,
            sortOrder: sortOrder,
            seriesID: seriesID,
            replacedHabitID: replacedHabitID,
            versionNumber: versionNumber,
            startDate: startDate,
            endDate: endDate,
            frequency: frequency,
            targetDaysOfWeek: targetDaysOfWeek,
            goalType: .count,
            goalCount: goalCount,
            goalUnit: "pages",
            currentStreak: currentStreak,
            longestStreak: longestStreak,
            lastCompletedDate: lastCompletedDate,
            reminders: [],
            entries: entries
        )
    }

    static func makeDraft(
        name: String = "Read",
        startDate: Date = date(2024, 1, 1),
        endDate: Date? = nil,
        frequency: HabitFrequency = .daily,
        targetDaysOfWeek: [Int] = [],
        goalCount: Int = 2
    ) -> HabitDraft {
        HabitDraft(
            name: name,
            description: "",
            icon: "book",
            colorHex: "#00AA00",
            startDate: startDate,
            endDate: endDate,
            frequency: frequency,
            targetDaysOfWeek: targetDaysOfWeek,
            goalType: .count,
            goalCount: goalCount,
            goalUnit: "pages",
            reminders: []
        )
    }
}
