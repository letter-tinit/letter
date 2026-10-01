import Foundation
import SwiftData
import XCTest
@testable import Data
@testable import Domain

@MainActor
final class ImpHabitRepositoryTests: XCTestCase {
    func test_updateHabit_persistsEditedGoalAndScheduleWithoutReplacingHistory() throws {
        let container = try HabitRepositoryTestSupport.makeContainer()
        let repository = ImpHabitRepository(modelContext: ModelContext(container))
        let id = uuid(80)
        _ = try repository.createHabit(from: makeDraft(), id: id, createdAt: date(100), sortOrder: 4)
        let streak = HabitStreakValues(current: 0, longest: 0, lastCompletedDate: nil)
        _ = try repository.persistEntry(
            HabitEntryValues(date: date(500), completedCount: 4, status: .active, note: nil, updatedAt: date(600)),
            habitID: id, streak: streak
        )
        let drafts = [
            makeDraft(frequency: .weekday, weekdays: [1, 2, 3, 4, 5], goalCount: 9, goalUnit: "chapters"),
            makeDraft(frequency: .weekend, weekdays: [0, 6], goalType: .todo, goalCount: 1, goalUnit: "times")
        ]
        for draft in drafts {
            _ = try repository.updateHabit(id: id, from: draft, streak: streak)
            let reader = ImpHabitRepository(modelContext: ModelContext(container))
            let saved = try XCTUnwrap(reader.fetchHabitSnapshots().first)
            XCTAssertEqual(saved.frequency, draft.frequency)
            XCTAssertEqual(saved.targetDaysOfWeek, draft.targetDaysOfWeek)
            XCTAssertEqual(saved.goalType, draft.goalType)
            XCTAssertEqual(saved.goalCount, draft.goalCount)
            XCTAssertEqual(saved.goalUnit, draft.goalUnit)
            XCTAssertEqual(saved.entries.map(\.completedCount), [4])
            XCTAssertEqual(saved.id, id)
            XCTAssertEqual(saved.createdAt, date(100))
            XCTAssertEqual(saved.sortOrder, 4)
        }
    }
    func test_createHabit_persistsDraftAndReturnsSnapshotWithSortedReminders() throws {
        let repository = try makeRepository()
        let id = uuid(1)
        let createdAt = date(100)
        let draft = makeDraft(
            name: "Read",
            description: "Twenty pages",
            reminders: [
                makeReminder(id: uuid(11), notificationID: "late", time: date(800), daysOfWeek: [2]),
                makeReminder(id: uuid(10), notificationID: "early", time: date(400), daysOfWeek: [1])
            ]
        )

        let snapshot = try repository.createHabit(
            from: draft,
            id: id,
            createdAt: createdAt,
            sortOrder: 7
        )

        XCTAssertEqual(snapshot.id, id)
        XCTAssertEqual(snapshot.name, "Read")
        XCTAssertEqual(snapshot.habitDescription, "Twenty pages")
        XCTAssertEqual(snapshot.createdAt, createdAt)
        XCTAssertEqual(snapshot.sortOrder, 7)
        XCTAssertEqual(snapshot.frequency, .custom)
        XCTAssertEqual(snapshot.targetDaysOfWeek, [1, 3, 5])
        XCTAssertEqual(snapshot.goalType, .count)
        XCTAssertEqual(snapshot.goalCount, 20)
        XCTAssertEqual(snapshot.goalUnit, "pages")
        XCTAssertEqual(snapshot.reminders.map(\.notificationID), ["early", "late"])

        let fetched = try XCTUnwrap(repository.fetchHabitSnapshots().first)
        XCTAssertEqual(fetched.id, id)
        XCTAssertEqual(fetched.reminders.map(\.id), [uuid(10), uuid(11)])
    }

    func test_fetchHabitSnapshots_sortsBySortOrderThenCreatedAtDescending() throws {
        let repository = try makeRepository()
        _ = try repository.createHabit(from: makeDraft(name: "Low"), id: uuid(2), createdAt: date(100), sortOrder: 1)
        _ = try repository.createHabit(from: makeDraft(name: "Newest"), id: uuid(3), createdAt: date(300), sortOrder: 2)
        _ = try repository.createHabit(from: makeDraft(name: "Older"), id: uuid(4), createdAt: date(200), sortOrder: 2)

        let snapshots = try repository.fetchHabitSnapshots()

        XCTAssertEqual(snapshots.map(\.name), ["Low", "Newest", "Older"])
    }

    func test_updateHabit_replacesReminderRecordsAndAppliesStreak() throws {
        let repository = try makeRepository()
        let id = uuid(5)
        _ = try repository.createHabit(
            from: makeDraft(reminders: [makeReminder(id: uuid(50), notificationID: "old", time: date(100))]),
            id: id,
            createdAt: date(100),
            sortOrder: 1
        )

        let updated = try XCTUnwrap(repository.updateHabit(
            id: id,
            from: makeDraft(
                name: "Meditate",
                description: "Ten minutes",
                reminders: [makeReminder(id: uuid(51), notificationID: "new", time: date(200), daysOfWeek: [4])]
            ),
            streak: HabitStreakValues(current: 3, longest: 5, lastCompletedDate: date(300))
        ))

        XCTAssertEqual(updated.name, "Meditate")
        XCTAssertEqual(updated.habitDescription, "Ten minutes")
        XCTAssertEqual(updated.currentStreak, 3)
        XCTAssertEqual(updated.longestStreak, 5)
        XCTAssertEqual(updated.lastCompletedDate, date(300))
        XCTAssertEqual(updated.reminders.map(\.notificationID), ["new"])

        let records = try repository.fetchHabits()
        XCTAssertEqual(records.first?.reminders.count, 1)
    }

    func test_persistEntry_updatesExistingEntryForSameStoredDayAndStreak() throws {
        let repository = try makeRepository()
        let id = uuid(6)
        _ = try repository.createHabit(from: makeDraft(), id: id, createdAt: date(100), sortOrder: 1)

        _ = try repository.persistEntry(
            HabitEntryValues(date: date(500), completedCount: 1, status: .active, note: "first", updatedAt: date(600)),
            habitID: id,
            streak: HabitStreakValues(current: 1, longest: 1, lastCompletedDate: date(500))
        )
        let updated = try XCTUnwrap(repository.persistEntry(
            HabitEntryValues(date: date(500), completedCount: 2, status: .skipped, note: nil, updatedAt: date(700)),
            habitID: id,
            streak: HabitStreakValues(current: 0, longest: 1, lastCompletedDate: nil)
        ))

        XCTAssertEqual(updated.entries.count, 1)
        XCTAssertEqual(updated.entries.first?.completedCount, 2)
        XCTAssertEqual(updated.entries.first?.status, .skipped)
        XCTAssertEqual(updated.currentStreak, 0)
        XCTAssertEqual(updated.longestStreak, 1)
        XCTAssertNil(updated.lastCompletedDate)
    }

    func test_deleteHabit_removesHabitAndCascadesEntriesAndReminders() throws {
        let repository = try makeRepository()
        let id = uuid(7)
        _ = try repository.createHabit(
            from: makeDraft(reminders: [makeReminder(id: uuid(70), notificationID: "delete", time: date(100))]),
            id: id,
            createdAt: date(100),
            sortOrder: 1
        )
        _ = try repository.persistEntry(
            HabitEntryValues(date: date(200), completedCount: 1, status: .active, note: nil, updatedAt: date(300)),
            habitID: id,
            streak: HabitStreakValues(current: 1, longest: 1, lastCompletedDate: date(200))
        )

        XCTAssertTrue(try repository.deleteHabit(id: id))

        XCTAssertTrue(try repository.fetchHabitSnapshots().isEmpty)
        XCTAssertTrue(try repository.fetchHabits().isEmpty)
    }

    func test_completeHabit_persistsCompletionDate() throws {
        let repository = try makeRepository()
        let id = uuid(8)
        _ = try repository.createHabit(from: makeDraft(), id: id, createdAt: date(100), sortOrder: 1)

        let completed = try XCTUnwrap(repository.completeHabit(id: id, completedAt: date(500)))

        XCTAssertEqual(completed.completedAt, date(500))
        XCTAssertEqual(try repository.fetchHabitSnapshots().first?.completedAt, date(500))
    }

    func test_profilePreferences_roundTripThroughDomainSnapshot() throws {
        let repository = try makeRepository()

        let created = try repository.createDefaultUserProfile()
        let weekStart = try XCTUnwrap(repository.updateProfileWeekStart(false))
        let colorScheme = try XCTUnwrap(repository.updateProfileColorScheme(.dark))
        try repository.setUsesCompactStatisticsView(true)

        XCTAssertEqual(created.displayName, "You")
        XCTAssertFalse(weekStart.weekStartsOnMonday)
        XCTAssertEqual(colorScheme.colorScheme, .dark)
        XCTAssertTrue(try repository.fetchUsesCompactStatisticsView())
    }

    private func makeRepository() throws -> ImpHabitRepository {
        let container = try HabitRepositoryTestSupport.makeContainer()
        return ImpHabitRepository(modelContext: ModelContext(container))
    }

    private func makeDraft(
        name: String = "Hydrate",
        description: String = "Drink water",
        frequency: HabitFrequency = .custom,
        weekdays: [Int] = [1, 3, 5],
        goalType: GoalType = .count,
        goalCount: Int = 20,
        goalUnit: String = "pages",
        reminders: [HabitReminderConfiguration] = []
    ) -> HabitDraft {
        HabitDraft(
            name: name,
            description: description,
            icon: "drop.fill",
            colorHex: "#4ECDC4",
            startDate: date(10),
            endDate: date(900),
            frequency: frequency,
            targetDaysOfWeek: weekdays,
            goalType: goalType,
            goalCount: goalCount,
            goalUnit: goalUnit,
            reminders: reminders
        )
    }

    private func makeReminder(
        id: UUID,
        notificationID: String,
        time: Date,
        daysOfWeek: [Int] = [],
        isEnabled: Bool = true
    ) -> HabitReminderConfiguration {
        HabitReminderConfiguration(
            id: id,
            notificationID: notificationID,
            time: time,
            daysOfWeek: daysOfWeek,
            isEnabled: isEnabled
        )
    }

    private func uuid(_ value: Int) -> UUID {
        UUID(uuidString: String(format: "00000000-0000-0000-0000-%012d", value))!
    }

    private func date(_ value: TimeInterval) -> Date {
        Date(timeIntervalSince1970: value)
    }
}
