import XCTest
@testable import Domain

@MainActor
final class HabitHomeUseCaseTests: XCTestCase {
    private let calendar = HabitTestSupport.calendar

    func test_updateEntry_persistsMutationWithRecalculatedStreak() throws {
        let habit = HabitTestSupport.makeHabit()
        let repository = FakeHabitRepository(habits: [habit])
        let notifications = FakeHabitNotificationRepository()
        let useCase = ImpHabitHomeUseCase(repository: repository, notifications: notifications)

        let change = try useCase.updateEntry(
            for: habit,
            on: HabitTestSupport.date(2024, 1, 2),
            completedCount: 2,
            note: "done",
            calendar: calendar,
            now: HabitTestSupport.date(2024, 1, 5)
        )

        XCTAssertEqual(change, .updated)
        XCTAssertEqual(repository.persistedEntries.count, 1)
        XCTAssertEqual(repository.persistedEntries.first?.values.note, "done")
        XCTAssertEqual(repository.persistedEntries.first?.streak.current, 1)
    }

    func test_updateEntry_returnsRejectedWithoutPersistenceForFutureDate() throws {
        let habit = HabitTestSupport.makeHabit()
        let repository = FakeHabitRepository(habits: [habit])
        let useCase = ImpHabitHomeUseCase(
            repository: repository,
            notifications: FakeHabitNotificationRepository()
        )

        let change = try useCase.updateEntry(
            for: habit,
            on: HabitTestSupport.date(2024, 1, 6),
            completedCount: 1,
            note: nil,
            calendar: calendar,
            now: HabitTestSupport.date(2024, 1, 5)
        )

        XCTAssertEqual(change, .rejected)
        XCTAssertTrue(repository.persistedEntries.isEmpty)
    }

    func test_rescheduleNotifications_forwardsEachHabit() {
        let habits = [HabitTestSupport.makeHabit(id: UUID()), HabitTestSupport.makeHabit(id: UUID())]
        let notifications = FakeHabitNotificationRepository()
        let useCase = ImpHabitHomeUseCase(
            repository: FakeHabitRepository(habits: habits),
            notifications: notifications
        )

        useCase.rescheduleNotifications(for: habits)

        XCTAssertEqual(notifications.rescheduledHabitIDs, habits.map(\.id))
    }
}
