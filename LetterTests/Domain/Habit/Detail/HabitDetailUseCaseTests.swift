import XCTest
@testable import Domain

@MainActor
final class HabitDetailUseCaseTests: XCTestCase {
    func test_load_includesPreviousNextAndSeriesCount() throws {
        let seriesID = UUID()
        let previous = HabitTestSupport.makeHabit(seriesID: seriesID, versionNumber: 1)
        let current = HabitTestSupport.makeHabit(
            seriesID: seriesID,
            replacedHabitID: previous.id,
            versionNumber: 2
        )
        let next = HabitTestSupport.makeHabit(
            seriesID: seriesID,
            replacedHabitID: current.id,
            versionNumber: 3
        )
        let useCase = ImpHabitDetailUseCase(
            repository: FakeHabitRepository(habits: [previous, current, next]),
            notifications: FakeHabitNotificationRepository()
        )

        let data = try useCase.load(habitID: current.id)

        XCTAssertEqual(data?.previousVersionNumber, 1)
        XCTAssertEqual(data?.nextVersionNumber, 3)
        XCTAssertEqual(data?.seriesHabitCount, 3)
    }

    func test_setArchived_cancelsNotificationAndPersistsArchive() throws {
        let habit = HabitTestSupport.makeHabit()
        let repository = FakeHabitRepository(habits: [habit])
        let notifications = FakeHabitNotificationRepository()
        let useCase = ImpHabitDetailUseCase(repository: repository, notifications: notifications)
        let now = HabitTestSupport.date(2024, 1, 5)

        try useCase.setArchived(true, habitID: habit.id, now: now)

        XCTAssertEqual(notifications.cancelledHabitIDs, [habit.id])
        XCTAssertEqual(repository.archivedInputs.first?.archived, true)
        XCTAssertEqual(repository.archivedInputs.first?.date, now)
    }

    func test_deleteSeries_cancelsAndDeletesAllHabitsInSeries() throws {
        let seriesID = UUID()
        let first = HabitTestSupport.makeHabit(seriesID: seriesID)
        let second = HabitTestSupport.makeHabit(seriesID: seriesID, replacedHabitID: first.id)
        let outside = HabitTestSupport.makeHabit()
        let repository = FakeHabitRepository(habits: [first, second, outside])
        let notifications = FakeHabitNotificationRepository()
        let useCase = ImpHabitDetailUseCase(repository: repository, notifications: notifications)

        try useCase.deleteSeries(containing: first.id)

        XCTAssertEqual(Set(notifications.cancelledHabitIDs), [first.id, second.id])
        XCTAssertEqual(repository.deletedHabitIDSets.first, [first.id, second.id])
        XCTAssertEqual(repository.habits.map(\.id), [outside.id])
    }
}
