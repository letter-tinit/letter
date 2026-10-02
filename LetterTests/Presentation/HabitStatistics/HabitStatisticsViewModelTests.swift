import XCTest
@testable import Domain
@testable import Presentation

@MainActor
final class HabitStatisticsViewModelTests: XCTestCase {
    private func model(_ spy: HabitStatisticsSpy, preferences: CalendarPreferences = CalendarPreferences()) -> HabitStatisticsViewModel {
        HabitStatisticsViewModel(useCase: spy, calendarPreferences: preferences)
    }

    func testReloadLoadsSnapshotsAndPersistedCompactPreference() {
        let spy = HabitStatisticsSpy()
        let habit = HabitTestSupport.makeHabit()
        spy.habits = [habit]
        spy.compact = true
        let vm = model(spy)
        vm.reload()
        XCTAssertEqual(vm.habits.map(\.id), [habit.id])
        XCTAssertTrue(vm.usesCompactStatisticsView)
    }

    func testFailedReloadClearsPreviousStateAndRetryRestoresIt() {
        let spy = HabitStatisticsSpy()
        spy.habits = [HabitTestSupport.makeHabit()]
        spy.compact = true
        let vm = model(spy)
        vm.reload()
        spy.loadError = HabitPresentationError.unavailable
        vm.reload()
        XCTAssertTrue(vm.habits.isEmpty)
        XCTAssertFalse(vm.usesCompactStatisticsView)
        spy.loadError = nil
        vm.reload()
        XCTAssertEqual(vm.habits.count, 1)
        XCTAssertTrue(vm.usesCompactStatisticsView)
    }

    func testFailedCompactWritePreservesStateAndRetryTogglesBothWays() {
        let spy = HabitStatisticsSpy()
        let vm = model(spy)
        spy.writeError = HabitPresentationError.unavailable
        vm.toggleCompactStatisticsView()
        XCTAssertFalse(vm.usesCompactStatisticsView)
        spy.writeError = nil
        vm.toggleCompactStatisticsView()
        XCTAssertTrue(vm.usesCompactStatisticsView)
        vm.toggleCompactStatisticsView()
        XCTAssertFalse(vm.usesCompactStatisticsView)
        XCTAssertEqual(spy.writes, [true, true, false])
    }

    func testScopeDispatchUsesCurrentCalendarPreferences() {
        let spy = HabitStatisticsSpy()
        let preferences = CalendarPreferences()
        let vm = model(spy, preferences: preferences)
        let date = HabitTestSupport.date(2024, 1, 1)
        XCTAssertEqual(vm.dates(scope: .week, containing: date), spy.returnedDates)
        preferences.update(weekStartsOnMonday: false)
        XCTAssertEqual(vm.dates(scope: .month, containing: date), spy.returnedDates)
        XCTAssertEqual(vm.dates(scope: .year, containing: date), spy.returnedDates)
        XCTAssertEqual(spy.requestedComponents, [.weekOfYear, .month, .year])
        XCTAssertEqual(spy.requestedCalendars.map(\.firstWeekday), [2, 1, 1])
        XCTAssertEqual(vm.orderedWeekdays, [0, 1, 2, 3, 4, 5, 6])
    }

    func testAggregateSummaryAndDayStatisticsUseLoadedHabits() {
        let spy = HabitStatisticsSpy()
        let habits = [HabitTestSupport.makeHabit(), HabitTestSupport.makeHabit()]
        spy.habits = habits
        let vm = model(spy)
        vm.reload()
        let summary = vm.statisticSummary(scope: .month, containing: spy.returnedDates[0])
        XCTAssertEqual(summary.progress, 0.4)
        XCTAssertEqual(summary.totalCompletedCount, 4)
        XCTAssertEqual(summary.totalTargetCount, 10)
        XCTAssertEqual(spy.aggregateIDs, habits.map(\.id))
        XCTAssertEqual(spy.summaryDates, spy.returnedDates)
        let dates = [HabitTestSupport.date(2024, 2, 1)]
        _ = vm.aggregateDayStatistics(dates: dates)
        XCTAssertEqual(spy.summaryDates, dates)
        XCTAssertEqual(spy.aggregateIDs, habits.map(\.id))
    }

    func testAvailabilityCacheInvalidatesAfterReloadAndCalendarChange() {
        let spy = HabitStatisticsSpy()
        let habit = HabitTestSupport.makeHabit(startDate: HabitTestSupport.date(2024, 1, 1), endDate: HabitTestSupport.date(2024, 1, 2))
        spy.habits = [habit]
        let preferences = CalendarPreferences()
        let vm = model(spy, preferences: preferences)
        vm.reload()
        XCTAssertTrue(vm.isVisible(habit, scope: .month, date: HabitTestSupport.date(2024, 1, 1)))
        XCTAssertFalse(vm.isVisible(habit, scope: .month, date: HabitTestSupport.date(2024, 2, 1)))
        XCTAssertEqual(spy.availabilityCalls, 1)
        vm.reload()
        _ = vm.availablePeriods(scope: .month)
        XCTAssertEqual(spy.availabilityCalls, 2)
        preferences.update(weekStartsOnMonday: false)
        _ = vm.availablePeriods(scope: .week)
        XCTAssertEqual(spy.availabilityCalls, 3)
        spy.habits = []
        vm.reload()
        XCTAssertTrue(vm.availablePeriods(scope: .month).isEmpty)
    }

    func testIndividualSummaryReturnsUseCaseOutputForRequestedHabit() {
        let spy = HabitStatisticsSpy()
        let habit = HabitTestSupport.makeHabit()
        let vm = model(spy)
        let summary = vm.statisticSummary(for: habit, scope: .year, containing: spy.returnedDates[0])
        XCTAssertEqual(spy.requestedHabitID, habit.id)
        XCTAssertEqual(spy.requestedComponents, [.year])
        XCTAssertEqual(spy.summaryDates, spy.returnedDates)
        XCTAssertEqual(summary.progress, 0.4)
        XCTAssertEqual(summary.scheduledDays, 5)
        XCTAssertEqual(summary.completedDays, 2)
        XCTAssertEqual(summary.skippedDays, 1)
        XCTAssertEqual(summary.totalCompletedCount, 4)
        XCTAssertEqual(summary.totalTargetCount, 10)
    }

    func testDayStatisticsReturnsUseCaseOutputInBothModes() throws {
        let spy = HabitStatisticsSpy()
        let habit = HabitTestSupport.makeHabit()
        let date = HabitTestSupport.date(2024, 1, 1)
        spy.habits = [habit]
        spy.returnedStatistics = [date: HabitDayStatistic(isScheduled: true, isSkipped: false, progress: 0.4)]
        let vm = model(spy)
        vm.reload()
        let individual = try XCTUnwrap(vm.dayStatistics(for: habit, dates: [date])[date])
        XCTAssertEqual(spy.requestedHabitID, habit.id)
        XCTAssertEqual(individual.progress, 0.4)
        XCTAssertTrue(individual.isScheduled)
        let aggregate = try XCTUnwrap(vm.aggregateDayStatistics(dates: [date])[date])
        XCTAssertEqual(spy.aggregateIDs, [habit.id])
        XCTAssertEqual(spy.summaryDates, [date])
        XCTAssertEqual(aggregate.progress, 0.4)
        XCTAssertFalse(aggregate.isSkipped)
    }

}
