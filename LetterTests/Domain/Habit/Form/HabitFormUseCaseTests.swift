import XCTest
@testable import Domain

@MainActor
final class HabitFormUseCaseTests: XCTestCase {
    private let calendar = HabitTestSupport.calendar

    func test_editRecalculatesStreakUsingNewGoalCount() {
        let habit = HabitTestSupport.makeHabit(goalCount: 2, entries: [
            HabitEntrySnapshot(date: HabitTestSupport.date(2024, 1, 1), completedCount: 1, status: .active),
            HabitEntrySnapshot(date: HabitTestSupport.date(2024, 1, 2), completedCount: 1, status: .active)
        ])
        let useCase = ImpHabitFormUseCase(repository: FakeHabitRepository(), notifications: FakeHabitNotificationRepository())
        let lowered = useCase.calculateStreak(for: habit, using: HabitTestSupport.makeDraft(goalCount: 1), calendar: calendar)
        XCTAssertEqual(lowered.current, 2)
        XCTAssertEqual(lowered.longest, 2)
        let raised = useCase.calculateStreak(for: habit, using: HabitTestSupport.makeDraft(goalCount: 3), calendar: calendar)
        XCTAssertEqual(raised.current, 0)
        XCTAssertNil(raised.lastCompletedDate)
    }

    func test_editRecalculatesStreakUsingNewScheduledWeekdays() {
        let habit = HabitTestSupport.makeHabit(entries: [
            HabitEntrySnapshot(date: HabitTestSupport.date(2024, 1, 1), completedCount: 2, status: .active),
            HabitEntrySnapshot(date: HabitTestSupport.date(2024, 1, 3), completedCount: 2, status: .active)
        ])
        let draft = HabitTestSupport.makeDraft(frequency: .custom, targetDaysOfWeek: [1, 3])
        let useCase = ImpHabitFormUseCase(repository: FakeHabitRepository(), notifications: FakeHabitNotificationRepository())
        let streak = useCase.calculateStreak(for: habit, using: draft, calendar: calendar)
        XCTAssertEqual(streak.current, 2)
        XCTAssertEqual(streak.longest, 2)
        XCTAssertEqual(streak.lastCompletedDate, HabitTestSupport.date(2024, 1, 3))
    }

    func test_saveCreate_assignsNextSortOrderAndReschedulesCreatedHabit() throws {
        let existing = HabitTestSupport.makeHabit(sortOrder: 2)
        let repository = FakeHabitRepository(habits: [existing])
        let notifications = FakeHabitNotificationRepository()
        let useCase = ImpHabitFormUseCase(repository: repository, notifications: notifications)

        let id = try useCase.save(
            mode: .create,
            draft: HabitTestSupport.makeDraft(name: "Write"),
            calendar: calendar,
            now: HabitTestSupport.date(2024, 1, 5)
        )

        XCTAssertEqual(repository.createdHabitInputs.first?.sortOrder, 3)
        XCTAssertEqual(notifications.rescheduledHabitIDs, [id])
    }

    func test_saveEdit_cancelsSourceAndReschedulesUpdatedHabit() throws {
        let habit = HabitTestSupport.makeHabit()
        let repository = FakeHabitRepository(habits: [habit])
        let notifications = FakeHabitNotificationRepository()
        let useCase = ImpHabitFormUseCase(repository: repository, notifications: notifications)

        let id = try useCase.save(
            mode: .edit(habit.id),
            draft: HabitTestSupport.makeDraft(name: "Updated"),
            calendar: calendar,
            now: HabitTestSupport.date(2024, 1, 5)
        )

        XCTAssertEqual(id, habit.id)
        XCTAssertEqual(notifications.cancelledHabitIDs, [habit.id])
        XCTAssertEqual(notifications.rescheduledHabitIDs, [habit.id])
        XCTAssertEqual(repository.updatedHabitInputs.first?.draft.name, "Updated")
    }

}
