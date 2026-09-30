import XCTest
@testable import Domain

final class HabitStatisticsAvailabilityTests: XCTestCase {
    private let calendar = HabitTestSupport.calendar

    func test_availabilityIncludesMissingEntriesFromHabitStartThroughToday() {
        let habit = HabitTestSupport.makeHabit(
            startDate: HabitTestSupport.date(2024, 1, 1),
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

        XCTAssertEqual(availability.ranges[habit.id]?.start, HabitTestSupport.date(2024, 1, 1))
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

    func test_completedHabit_isVisibleOnlyForPeriodsIntersectingCompletionDate() {
        var mondayCalendar = calendar
        mondayCalendar.firstWeekday = 2
        let habit = HabitTestSupport.makeHabit(
            startDate: HabitTestSupport.date(2026, 8, 1),
            completedAt: HabitTestSupport.date(2026, 8, 30),
            entries: [entry(HabitTestSupport.date(2026, 8, 30))]
        )
        let availability = HabitStatisticsAvailability(
            habits: [habit],
            today: HabitTestSupport.date(2027, 1, 1),
            calendar: mondayCalendar
        )

        XCTAssertTrue(availability.includes(
            habitID: habit.id,
            period: interval(.weekOfYear, containing: HabitTestSupport.date(2026, 8, 30), calendar: mondayCalendar)
        ))
        XCTAssertFalse(availability.includes(
            habitID: habit.id,
            period: interval(.weekOfYear, containing: HabitTestSupport.date(2026, 8, 31), calendar: mondayCalendar)
        ))
        XCTAssertTrue(availability.includes(
            habitID: habit.id,
            period: interval(.month, containing: HabitTestSupport.date(2026, 8, 8))
        ))
        XCTAssertFalse(availability.includes(
            habitID: habit.id,
            period: interval(.month, containing: HabitTestSupport.date(2026, 9, 1))
        ))
        XCTAssertTrue(availability.includes(
            habitID: habit.id,
            period: interval(.year, containing: HabitTestSupport.date(2026, 1, 1))
        ))
        XCTAssertFalse(availability.includes(
            habitID: habit.id,
            period: interval(.year, containing: HabitTestSupport.date(2027, 1, 1))
        ))
    }

    private func entry(_ date: Date) -> HabitEntrySnapshot {
        HabitEntrySnapshot(
            date: date,
            completedCount: 1,
            status: .active
        )
    }

    private func interval(
        _ component: Calendar.Component,
        containing date: Date,
        calendar: Calendar? = nil
    ) -> DateInterval {
        let calendar = calendar ?? self.calendar
        return calendar.dateInterval(of: component, for: date)!
    }
}
