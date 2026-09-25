import XCTest
@testable import Domain

@MainActor
final class HabitDetailUseCaseTests: XCTestCase {
    func test_load_returnsHabitDetailData() throws {
        let habit = HabitTestSupport.makeHabit()
        let useCase = ImpHabitDetailUseCase(
            repository: FakeHabitRepository(habits: [habit]),
            notifications: FakeHabitNotificationRepository()
        )

        let data = try useCase.load(habitID: habit.id)

        XCTAssertEqual(data?.habit.id, habit.id)
    }

    func test_delete_cancelsNotificationAndDeletesHabit() throws {
        let habit = HabitTestSupport.makeHabit()
        let repository = FakeHabitRepository(habits: [habit])
        let notifications = FakeHabitNotificationRepository()
        let useCase = ImpHabitDetailUseCase(repository: repository, notifications: notifications)

        try useCase.delete(habitID: habit.id)

        XCTAssertEqual(notifications.cancelledHabitIDs, [habit.id])
        XCTAssertEqual(repository.deletedHabitInputs, [habit.id])
    }
}
