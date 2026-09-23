import XCTest
@testable import Domain

final class HabitScheduleUseCaseTests: XCTestCase {
    private let useCase = ImpHabitScheduleUseCase()
    private let calendar = HabitTestSupport.calendar

    func test_daily_isScheduledBetweenStartAndEndDates() {
        let habit = HabitTestSupport.makeHabit(
            startDate: HabitTestSupport.date(2024, 1, 2),
            endDate: HabitTestSupport.date(2024, 1, 4),
            frequency: .daily
        )

        XCTAssertFalse(useCase.isScheduled(habit, on: HabitTestSupport.date(2024, 1, 1), calendar: calendar))
        XCTAssertTrue(useCase.isScheduled(habit, on: HabitTestSupport.date(2024, 1, 2), calendar: calendar))
        XCTAssertTrue(useCase.isScheduled(habit, on: HabitTestSupport.date(2024, 1, 4), calendar: calendar))
        XCTAssertFalse(useCase.isScheduled(habit, on: HabitTestSupport.date(2024, 1, 5), calendar: calendar))
    }

    func test_archivedAt_closesScheduleAfterArchivedDay() {
        let habit = HabitTestSupport.makeHabit(
            archivedAt: HabitTestSupport.date(2024, 1, 3),
            startDate: HabitTestSupport.date(2024, 1, 1),
            frequency: .daily
        )

        XCTAssertTrue(useCase.isScheduled(habit, on: HabitTestSupport.date(2024, 1, 3), calendar: calendar))
        XCTAssertFalse(useCase.isScheduled(habit, on: HabitTestSupport.date(2024, 1, 4), calendar: calendar))
    }

    func test_weekdayAndWeekend_useCalendarWeekday() {
        let weekdayHabit = HabitTestSupport.makeHabit(frequency: .weekday)
        let weekendHabit = HabitTestSupport.makeHabit(frequency: .weekend)

        XCTAssertTrue(useCase.isScheduled(weekdayHabit, on: HabitTestSupport.date(2024, 1, 1), calendar: calendar))
        XCTAssertFalse(useCase.isScheduled(weekdayHabit, on: HabitTestSupport.date(2024, 1, 6), calendar: calendar))
        XCTAssertFalse(useCase.isScheduled(weekendHabit, on: HabitTestSupport.date(2024, 1, 1), calendar: calendar))
        XCTAssertTrue(useCase.isScheduled(weekendHabit, on: HabitTestSupport.date(2024, 1, 6), calendar: calendar))
    }

    func test_custom_usesTargetDaysOfWeek() {
        let habit = HabitTestSupport.makeHabit(
            frequency: .custom,
            targetDaysOfWeek: [1, 3]
        )

        XCTAssertTrue(useCase.isScheduled(habit, on: HabitTestSupport.date(2024, 1, 1), calendar: calendar))
        XCTAssertFalse(useCase.isScheduled(habit, on: HabitTestSupport.date(2024, 1, 2), calendar: calendar))
        XCTAssertTrue(useCase.isScheduled(habit, on: HabitTestSupport.date(2024, 1, 3), calendar: calendar))
    }
}
