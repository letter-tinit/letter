import XCTest
@testable import Domain

final class HabitStatisticsAvailabilityTests: XCTestCase {
    private let calendar = HabitTestSupport.calendar

    func test_availabilityStartsAtFirstRecordAndEndsAtTodayPlusOneDay() {
        let habit = HabitTestSupport.makeHabit(
            entries: [
                entry(HabitTestSupport.date(2024, 1, 2)),
                entry(HabitTestSupport.date(2024, 1, 4))
            ]
        )

        let availability = HabitStatisticsAvailability(
            habits: [habit],
            today: HabitTestSupport.date(2024, 1, 5),
            calendar: calendar
        )

        XCTAssertEqual(availability.ranges[habit.id]?.start, HabitTestSupport.date(2024, 1, 2))
        XCTAssertEqual(availability.ranges[habit.id]?.end, HabitTestSupport.date(2024, 1, 6))
    }

    func test_periods_returnsOnlyIntersectingPeriodsForSelectedHabits() {
        let habit = HabitTestSupport.makeHabit(
            entries: [entry(HabitTestSupport.date(2024, 1, 31))]
        )
        let availability = HabitStatisticsAvailability(
            habits: [habit],
            today: HabitTestSupport.date(2024, 2, 2),
            calendar: calendar
        )

        let periods = availability.periods(
            for: [habit.id],
            component: .month,
            calendar: calendar
        )

        XCTAssertEqual(periods, [
            HabitTestSupport.date(2024, 1, 1),
            HabitTestSupport.date(2024, 2, 1)
        ])
    }

    private func entry(_ date: Date) -> HabitEntrySnapshot {
        HabitEntrySnapshot(
            date: date,
            completedCount: 1,
            status: .active
        )
    }
}
