import Foundation
import SwiftData
import XCTest
@testable import Data
@testable import Domain

@MainActor
final class HabitBackupPersistenceTests: XCTestCase {
    func test_exportBackup_includesProfileHabitsEntriesAndReminders() throws {
        let context = try makeContext()
        let repository = ImpHabitRepository(modelContext: context)
        let notifications = RecordingHabitNotificationRepository()
        let persistence = HabitBackupPersistence(repository: repository, notificationRepository: notifications)
        insertHabitGraph(into: repository)
        try repository.save()

        let backup = try persistence.exportBackup()

        XCTAssertEqual(backup.profile?.displayName, "Tester")
        XCTAssertEqual(backup.habits.map(\.id), [uuid(1)])
        let habit = try XCTUnwrap(backup.habits.first)
        XCTAssertEqual(habit.name, "Read")
        XCTAssertEqual(habit.entries.map(\.id), [uuid(2)])
        XCTAssertEqual(habit.reminders.map(\.id), [uuid(3)])
        XCTAssertEqual(habit.entries[0].status, .active)
        XCTAssertEqual(habit.reminders[0].notificationID, "reminder-3")
    }

    func test_importBackup_replacesDataRestoresGraphAndCancelsExistingNotifications() throws {
        let context = try makeContext()
        let repository = ImpHabitRepository(modelContext: context)
        let notifications = RecordingHabitNotificationRepository()
        let persistence = HabitBackupPersistence(repository: repository, notificationRepository: notifications)
        insertHabitGraph(into: repository, habitID: uuid(90), notificationID: "old-reminder")
        try repository.save()

        try persistence.importBackup(makeHabitBackup())

        XCTAssertEqual(notifications.cancelledHabitIDs, [uuid(90)])
        let profile = try XCTUnwrap(try repository.fetchUserProfileRecord())
        XCTAssertEqual(profile.id, uuid(10))
        XCTAssertEqual(profile.displayName, "Restored")
        XCTAssertEqual(profile.weekStartsOnMonday, false)
        XCTAssertEqual(profile.usesSimplifiedStatisticsMode, true)
        XCTAssertEqual(profile.themeColorHex, "#123456")

        let habit = try XCTUnwrap(try repository.fetchHabits().first)
        XCTAssertEqual(try repository.fetchHabits().map(\.id), [uuid(11)])
        XCTAssertEqual(habit.name, "Restore habit")
        XCTAssertEqual(habit.entries.map(\.id), [uuid(12)])
        XCTAssertEqual(habit.reminders.map(\.id), [uuid(13)])
        XCTAssertTrue(habit.entries[0].habit === habit)
        XCTAssertTrue(habit.reminders[0].habit === habit)
    }

    func test_importBackup_validatesBeforeDeletingExistingData() throws {
        let context = try makeContext()
        let repository = ImpHabitRepository(modelContext: context)
        let persistence = HabitBackupPersistence(
            repository: repository,
            notificationRepository: RecordingHabitNotificationRepository()
        )
        insertHabitGraph(into: repository)
        try repository.save()
        let invalid = makeHabitBackup(schemaVersion: HabitBackup.currentSchemaVersion + 1)

        XCTAssertThrowsError(try persistence.importBackup(invalid))

        XCTAssertEqual(try repository.fetchHabits().map(\.id), [uuid(1)])
        XCTAssertNotNil(try repository.fetchUserProfileRecord())
    }

    func test_clearAllData_removesHabitDataAndCancelsNotifications() throws {
        let context = try makeContext()
        let repository = ImpHabitRepository(modelContext: context)
        let notifications = RecordingHabitNotificationRepository()
        let persistence = HabitBackupPersistence(repository: repository, notificationRepository: notifications)
        insertHabitGraph(into: repository)
        try repository.save()

        try persistence.clearAllData()

        XCTAssertEqual(notifications.cancelledHabitIDs, [uuid(1)])
        XCTAssertTrue(try repository.fetchHabits().isEmpty)
        XCTAssertNil(try repository.fetchUserProfileRecord())
        XCTAssertTrue(try context.fetch(FetchDescriptor<HabitEntry>()).isEmpty)
        XCTAssertTrue(try context.fetch(FetchDescriptor<HabitReminder>()).isEmpty)
    }

    private func makeContext() throws -> ModelContext {
        try ModelContext(HabitRepositoryTestSupport.makeContainer())
    }
}

@MainActor
private final class RecordingHabitNotificationRepository: HabitNotificationRepository {
    private(set) var cancelledHabitIDs: [UUID] = []

    func rescheduleNotifications(for habit: HabitSnapshot) {}

    func cancelNotifications(for habit: HabitSnapshot) {
        cancelledHabitIDs.append(habit.id)
    }
}

@MainActor
private func insertHabitGraph(
    into repository: ImpHabitRepository,
    habitID: UUID = uuid(1),
    notificationID: String = "reminder-3"
) {
    let profile = UserProfile(displayName: "Tester")
    profile.id = uuid(100)
    profile.weekStartsOnMonday = true
    repository.addProfile(profile)

    let habit = Habit(
        name: "Read",
        description: "Pages",
        icon: "book.fill",
        colorHex: "#ABCDEF",
        startDate: date(100),
        frequency: .custom,
        targetDaysOfWeek: [1, 3],
        goalType: .count,
        goalCount: 20,
        goalUnit: "pages"
    )
    habit.id = habitID
    habit.createdAt = date(90)
    habit.sortOrder = 1
    habit.currentStreak = 2
    habit.longestStreak = 5

    let entry = HabitEntry(date: date(200), completedCount: 20, status: .active, note: "done")
    entry.id = uuid(2)
    entry.createdAt = date(201)
    entry.updatedAt = date(202)
    entry.habit = habit
    habit.entries = [entry]

    let reminder = HabitReminder(time: date(300), daysOfWeek: [1, 3], isEnabled: true)
    reminder.id = uuid(3)
    reminder.notificationID = notificationID
    reminder.habit = habit
    habit.reminders = [reminder]

    repository.addHabit(habit)
    repository.addEntry(entry)
    repository.addReminder(reminder)
}

private func makeHabitBackup(schemaVersion: Int = HabitBackup.currentSchemaVersion) -> HabitBackup {
    let profile = UserProfile(displayName: "Restored")
    profile.id = uuid(10)
    profile.weekStartsOnMonday = false
    profile.usesSimplifiedStatisticsMode = true
    profile.defaultReminderTime = date(10)
    profile.colorScheme = .dark
    profile.themeColorHex = "#123456"
    profile.totalCompletions = 7
    profile.totalHabitsCreated = 8
    profile.longestOverallStreak = 9
    profile.joinedAt = date(11)

    let habit = Habit(
        name: "Restore habit",
        description: "Restored description",
        icon: "flame.fill",
        colorHex: "#654321",
        startDate: date(100),
        endDate: date(900),
        frequency: .weekday,
        targetDaysOfWeek: [1, 2, 3, 4, 5],
        goalType: .count,
        goalCount: 3,
        goalUnit: "times"
    )
    habit.id = uuid(11)
    habit.createdAt = date(99)
    habit.sortOrder = 2
    habit.currentStreak = 4
    habit.longestStreak = 6
    habit.lastCompletedDate = date(500)

    let entry = HabitEntry(date: date(300), completedCount: 3, status: .active, note: "restored")
    entry.id = uuid(12)
    entry.createdAt = date(301)
    entry.updatedAt = date(302)
    entry.habit = habit
    habit.entries = [entry]

    let reminder = HabitReminder(time: date(400), daysOfWeek: [1, 2], isEnabled: true)
    reminder.id = uuid(13)
    reminder.notificationID = "restored-reminder"
    reminder.habit = habit
    habit.reminders = [reminder]

    var backup = HabitBackup(profile: profile, habits: [habit])
    backup.schemaVersion = schemaVersion
    backup.exportedAt = date(1_000)
    return backup
}

private func uuid(_ value: Int) -> UUID {
    UUID(uuidString: String(format: "00000000-0000-0000-0000-%012d", value))!
}

private func date(_ value: TimeInterval) -> Date {
    Date(timeIntervalSince1970: value)
}
