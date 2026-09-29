import XCTest
import Domain
@testable import Presentation

final class HabitStatisticDateLayoutTests: XCTestCase {
    private let calendar = HabitTestSupport.calendar

    func test_weekDates_preserveFullWeekIndexForCompletedHabit() {
        let week = dates(from: HabitTestSupport.date(2026, 8, 30), count: 7)

        XCTAssertEqual(HabitStatisticDateLayout.weekDates(week), week)
    }

    func test_monthDates_preserveLeadingPlaceholdersAndPostCompletionIndex() {
        let dates: [Date?] = [
            nil,
            HabitTestSupport.date(2026, 8, 30),
            HabitTestSupport.date(2026, 8, 31),
            HabitTestSupport.date(2026, 9, 1)
        ]

        XCTAssertEqual(HabitStatisticDateLayout.monthDates(dates), dates)
    }

    func test_yearWeeks_dropColumnsBeforeHabitStartsAndKeepFullIntersectingColumns() {
        let start = HabitTestSupport.date(2026, 7, 26)
        let weeks = stride(from: 0, through: 14, by: 7).map { offset in
            dates(from: calendar.date(byAdding: .day, value: offset, to: start)!, count: 7)
        }
        let statistics = [
            HabitTestSupport.date(2026, 8, 1): statistic(isAvailable: true),
            HabitTestSupport.date(2026, 8, 8): statistic(isAvailable: true)
        ]

        let displayedWeeks = HabitStatisticDateLayout.yearWeeks(
            weeks,
            dayStatistics: statistics,
            calendar: calendar
        )

        XCTAssertEqual(displayedWeeks, [weeks[0], weeks[1]])
    }

    func test_yearWeeks_keepCompletionColumnButDropColumnsAfterCompletion() {
        let start = HabitTestSupport.date(2026, 8, 23)
        let weeks = stride(from: 0, through: 14, by: 7).map { offset in
            dates(from: calendar.date(byAdding: .day, value: offset, to: start)!, count: 7)
        }
        let statistics = [
            HabitTestSupport.date(2026, 8, 30): statistic(isAvailable: true),
            HabitTestSupport.date(2026, 8, 31): statistic(isAvailable: false),
            HabitTestSupport.date(2026, 9, 6): statistic(isAvailable: false)
        ]

        let displayedWeeks = HabitStatisticDateLayout.yearWeeks(
            weeks,
            dayStatistics: statistics,
            calendar: calendar
        )

        XCTAssertEqual(displayedWeeks, [weeks[1]])
    }

    private func dates(from start: Date, count: Int) -> [Date] {
        (0..<count).map {
            calendar.date(byAdding: .day, value: $0, to: start)!
        }
    }

    private func statistic(isAvailable: Bool) -> HabitDayStatistic {
        HabitDayStatistic(
            isScheduled: isAvailable,
            isSkipped: false,
            progress: isAvailable ? 1 : 0,
            isAvailable: isAvailable,
            isCompletionDate: false
        )
    }
}
