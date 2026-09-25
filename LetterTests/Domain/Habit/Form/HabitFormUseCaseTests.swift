import XCTest
@testable import Domain

@MainActor
final class HabitFormUseCaseTests: XCTestCase {
    private let calendar = HabitTestSupport.calendar

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
