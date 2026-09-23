import XCTest
@testable import Domain

final class HabitStreakUseCaseTests: XCTestCase {
    private let useCase = ImpHabitStreakUseCase()
    private let calendar = HabitTestSupport.calendar

    func test_calculate_countsConsecutiveCompletedScheduledDays() {
        let habit = HabitTestSupport.makeHabit(
            entries: [
                entry(2024, 1, 1, completedCount: 2),
                entry(2024, 1, 2, completedCount: 2),
                entry(2024, 1, 3, completedCount: 2)
            ]
        )

        let result = useCase.calculate(
            schedule: habit,
            entries: habit.entries,
            goalCount: habit.goalCount,
            calendar: calendar
        )

        XCTAssertEqual(result.currentStreak, 3)
        XCTAssertEqual(result.longestStreak, 3)
        XCTAssertEqual(result.lastCompletedDate, HabitTestSupport.date(2024, 1, 3))
    }

    func test_calculate_skippedDaysBridgeCurrentStreakButDoNotIncreaseIt() {
        let habit = HabitTestSupport.makeHabit(
            entries: [
                entry(2024, 1, 1, completedCount: 2),
                entry(2024, 1, 2, completedCount: 0, status: .skipped),
                entry(2024, 1, 3, completedCount: 2)
            ]
        )

        let result = useCase.calculate(
            schedule: habit,
            entries: habit.entries,
            goalCount: habit.goalCount,
            calendar: calendar
        )

        XCTAssertEqual(result.currentStreak, 2)
        XCTAssertEqual(result.longestStreak, 2)
    }

    func test_calculate_ignoresUnscheduledCompletedDates() {
        let habit = HabitTestSupport.makeHabit(
            frequency: .custom,
            targetDaysOfWeek: [1, 3],
            entries: [
                entry(2024, 1, 1, completedCount: 2),
                entry(2024, 1, 2, completedCount: 2),
                entry(2024, 1, 3, completedCount: 2)
            ]
        )

        let result = useCase.calculate(
            schedule: habit,
            entries: habit.entries,
            goalCount: habit.goalCount,
            calendar: calendar
        )

        XCTAssertEqual(result.currentStreak, 2)
        XCTAssertEqual(result.longestStreak, 2)
    }

    private func entry(
        _ year: Int,
        _ month: Int,
        _ day: Int,
        completedCount: Int,
        status: HabitEntryStatus = .active
    ) -> HabitEntrySnapshot {
        HabitEntrySnapshot(
            date: HabitTestSupport.date(year, month, day),
            completedCount: completedCount,
            status: status
        )
    }
}
