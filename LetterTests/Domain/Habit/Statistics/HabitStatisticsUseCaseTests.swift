import XCTest
@testable import Domain

@MainActor
final class HabitStatisticsUseCaseTests: XCTestCase {
    private let calendar = HabitTestSupport.calendar

    func test_load_returnsHabitsAndCompactPreferenceFromRepository() throws {
        let habit = HabitTestSupport.makeHabit()
        let repository = FakeHabitRepository(habits: [habit])
        repository.usesCompactStatisticsView = true
        let useCase = ImpHabitStatisticsUseCase(repository: repository)

        let data = try useCase.load()

        XCTAssertEqual(data.habits.map(\.id), [habit.id])
        XCTAssertTrue(data.usesCompactView)
    }

    func test_setCompactViewEnabled_persistsPreference() throws {
        let repository = FakeHabitRepository()
        let useCase = ImpHabitStatisticsUseCase(repository: repository)

        try useCase.setCompactViewEnabled(true)

        XCTAssertTrue(repository.usesCompactStatisticsView)
    }

    func test_dayStatistics_marksSkippedDayAndProgress() {
        let date = HabitTestSupport.date(2024, 1, 2)
        let habit = HabitTestSupport.makeHabit(
            goalCount: 4,
            entries: [entry(date, completedCount: 0, status: .skipped)]
        )
        let useCase = ImpHabitStatisticsUseCase(repository: FakeHabitRepository(habits: [habit]))

        let statistics = useCase.dayStatistics(for: habit, dates: [date], calendar: calendar)

        XCTAssertEqual(statistics[date]?.isScheduled, true)
        XCTAssertEqual(statistics[date]?.isSkipped, true)
        XCTAssertEqual(statistics[date]?.progress, 0)
    }

    func test_aggregateDayStatistics_averagesActiveHabitProgress() {
        let date = HabitTestSupport.date(2024, 1, 2)
        let half = HabitTestSupport.makeHabit(
            id: UUID(),
            goalCount: 4,
            entries: [entry(date, completedCount: 2)]
        )
        let complete = HabitTestSupport.makeHabit(
            id: UUID(),
            goalCount: 4,
            entries: [entry(date, completedCount: 4)]
        )
        let useCase = ImpHabitStatisticsUseCase(repository: FakeHabitRepository(habits: [half, complete]))

        let statistics = useCase.aggregateDayStatistics(
            habits: [half, complete],
            dates: [date],
            calendar: calendar
        )

        XCTAssertEqual(statistics[date]?.isScheduled, true)
        XCTAssertEqual(statistics[date]?.progress, 0.75)
    }

    func test_summary_countsScheduledCompletedAndSkippedDays() {
        let dates = [
            HabitTestSupport.date(2024, 1, 1),
            HabitTestSupport.date(2024, 1, 2),
            HabitTestSupport.date(2024, 1, 3)
        ]
        let habit = HabitTestSupport.makeHabit(
            goalCount: 2,
            entries: [
                entry(dates[0], completedCount: 2),
                entry(dates[1], completedCount: 1),
                entry(dates[2], completedCount: 0, status: .skipped)
            ]
        )
        let useCase = ImpHabitStatisticsUseCase(repository: FakeHabitRepository(habits: [habit]))

        let summary = useCase.summary(for: habit, dates: dates, calendar: calendar)

        XCTAssertEqual(summary.scheduledDays, 2)
        XCTAssertEqual(summary.completedDays, 1)
        XCTAssertEqual(summary.skippedDays, 1)
        XCTAssertEqual(summary.totalCompletedCount, 3)
        XCTAssertEqual(summary.totalTargetCount, 4)
        XCTAssertEqual(summary.progress, 0.75)
    }

    func test_dates_returnsAllDaysInContainingComponent() {
        let useCase = ImpHabitStatisticsUseCase(repository: FakeHabitRepository())

        let dates = useCase.dates(
            in: .weekOfYear,
            containing: HabitTestSupport.date(2024, 1, 3),
            calendar: calendar
        )

        XCTAssertEqual(dates.count, 7)
        XCTAssertEqual(dates.first, HabitTestSupport.date(2023, 12, 31))
        XCTAssertEqual(dates.last, HabitTestSupport.date(2024, 1, 6))
    }

    private func entry(
        _ date: Date,
        completedCount: Int,
        status: HabitEntryStatus = .active
    ) -> HabitEntrySnapshot {
        HabitEntrySnapshot(
            date: date,
            completedCount: completedCount,
            status: status
        )
    }
}
