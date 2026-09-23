import XCTest
@testable import Domain

final class HabitVersionUseCaseTests: XCTestCase {
    private let useCase = ImpHabitVersionUseCase()
    private let calendar = HabitTestSupport.calendar

    func test_plan_startsNoEarlierThanTomorrowAndClosesSourceDayBefore() {
        let source = HabitTestSupport.makeHabit(startDate: HabitTestSupport.date(2024, 1, 1))

        let plan = useCase.plan(
            replacing: source,
            in: [source],
            proposedStartDate: HabitTestSupport.date(2024, 1, 2),
            now: HabitTestSupport.date(2024, 1, 5),
            calendar: calendar
        )

        XCTAssertEqual(plan.newStartDate, HabitTestSupport.date(2024, 1, 6))
        XCTAssertEqual(plan.sourceEndDate, HabitTestSupport.date(2024, 1, 5))
        XCTAssertEqual(plan.versionNumber, 2)
    }

    func test_plan_usesNextHighestSeriesVersionNumber() {
        let seriesID = UUID()
        let source = HabitTestSupport.makeHabit(
            seriesID: seriesID,
            versionNumber: 2,
            startDate: HabitTestSupport.date(2024, 1, 1)
        )
        let existingVersion = HabitTestSupport.makeHabit(
            seriesID: seriesID,
            versionNumber: 4,
            startDate: HabitTestSupport.date(2024, 1, 1)
        )

        let plan = useCase.plan(
            replacing: source,
            in: [source, existingVersion],
            proposedStartDate: HabitTestSupport.date(2024, 1, 10),
            now: HabitTestSupport.date(2024, 1, 5),
            calendar: calendar
        )

        XCTAssertEqual(plan.versionNumber, 5)
    }
}
