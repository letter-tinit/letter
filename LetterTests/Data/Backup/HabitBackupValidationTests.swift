import Foundation
import XCTest
@testable import Data
@testable import Domain

final class HabitBackupValidationTests: XCTestCase {
    func test_validate_rejectsDuplicateEntriesAndReminders() {
        let duplicateID = uuid(20)
        let habitWithDuplicateEntries = makeHabit()
        let firstEntry = HabitEntry(date: date(100), completedCount: 1)
        firstEntry.id = duplicateID
        let secondEntry = HabitEntry(date: date(200), completedCount: 1)
        secondEntry.id = duplicateID
        habitWithDuplicateEntries.entries = [firstEntry, secondEntry]

        assertInvalid(makeBackup(habit: habitWithDuplicateEntries))

        let habitWithDuplicateReminders = makeHabit()
        let firstReminder = HabitReminder(time: date(100))
        firstReminder.id = duplicateID
        let secondReminder = HabitReminder(time: date(200))
        secondReminder.id = duplicateID
        habitWithDuplicateReminders.reminders = [firstReminder, secondReminder]

        assertInvalid(makeBackup(habit: habitWithDuplicateReminders))
    }

    func test_validate_rejectsInvalidEntryAndReminderValues() {
        let skippedWithProgress = makeHabit()
        let skippedEntry = HabitEntry(date: date(100), completedCount: 1, status: .skipped)
        skippedWithProgress.entries = [skippedEntry]
        assertInvalid(makeBackup(habit: skippedWithProgress))

        let negativeProgress = makeHabit()
        negativeProgress.entries = [HabitEntry(date: date(100), completedCount: -1)]
        assertInvalid(makeBackup(habit: negativeProgress))

        let invalidReminderDay = makeHabit()
        invalidReminderDay.reminders = [HabitReminder(time: date(100), daysOfWeek: [7])]
        assertInvalid(makeBackup(habit: invalidReminderDay))

        let emptyNotificationID = makeHabit()
        let reminder = HabitReminder(time: date(100))
        reminder.notificationID = "  "
        emptyNotificationID.reminders = [reminder]
        assertInvalid(makeBackup(habit: emptyNotificationID))
    }

    func test_decodeHabitBackupItems_usesLegacyDefaults() throws {
        let id = uuid(1)
        let createdAt = date(100)
        let json = """
        {
          "id": "\(id.uuidString)",
          "name": "Legacy",
          "habitDescription": "",
          "icon": "star.fill",
          "colorHex": "#000000",
          "createdAt": \(createdAt.timeIntervalSince1970),
          "frequency": "daily",
          "targetDaysOfWeek": [],
          "goalType": "todo",
          "goalCount": 1,
          "goalUnit": "times",
          "currentStreak": 0,
          "longestStreak": 0,
          "entries": [
            {
              "id": "\(uuid(2).uuidString)",
              "date": \(date(200).timeIntervalSince1970),
              "completedCount": 1,
              "note": "",
              "createdAt": \(date(201).timeIntervalSince1970),
              "updatedAt": \(date(202).timeIntervalSince1970)
            }
          ],
          "reminders": []
        }
        """

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .secondsSince1970
        let item = try decoder.decode(HabitBackupItem.self, from: Data(json.utf8))

        XCTAssertEqual(item.sortOrder, 0)
        XCTAssertEqual(item.effectiveStartDate, createdAt)
        XCTAssertEqual(item.entries.first?.status, .active)
    }

    private func assertInvalid(_ backup: HabitBackup, file: StaticString = #filePath, line: UInt = #line) {
        XCTAssertThrowsError(try backup.validate(), file: file, line: line) { error in
            guard case HabitBackupError.invalidData = error else {
                XCTFail("Expected invalidData, got \(error)", file: file, line: line)
                return
            }
        }
    }

    private func makeBackup(habit: Habit) -> HabitBackup {
        HabitBackup(profile: nil, habits: [habit])
    }

    private func makeHabit(
        name: String = "Valid",
        goalCount: Int = 1,
        targetDaysOfWeek: [Int] = [],
        startDate: Date? = nil,
        endDate: Date? = nil
    ) -> Habit {
        Habit(
            name: name,
            startDate: startDate,
            endDate: endDate,
            frequency: .custom,
            targetDaysOfWeek: targetDaysOfWeek,
            goalCount: goalCount
        )
    }

}

private func uuid(_ value: Int) -> UUID {
    UUID(uuidString: String(format: "00000000-0000-0000-0000-%012d", value))!
}

private func date(_ value: TimeInterval) -> Date {
    Date(timeIntervalSince1970: value)
}
