import XCTest
@testable import Domain
@testable import Presentation

@MainActor
final class HabitViewModelTests: XCTestCase {
    private func model(_ spy: HabitHomeSpy, preferences: CalendarPreferences = CalendarPreferences()) -> HabitViewModel {
        HabitViewModel(useCase: spy, calendarPreferences: preferences)
    }

    func testInitializationLoadsSnapshotsAndFetchFailureCanRecover() {
        let spy = HabitHomeSpy()
        let habit = HabitTestSupport.makeHabit()
        spy.habits = [habit]
        let vm = model(spy)
        XCTAssertEqual(spy.fetchCount, 1)
        XCTAssertEqual(vm.habit(id: habit.id)?.id, habit.id)
        spy.fetchError = HabitPresentationError.unavailable
        vm.fetchHabits()
        XCTAssertNil(vm.habit(id: habit.id))
        spy.fetchError = nil
        vm.fetchHabits()
        XCTAssertEqual(vm.habit(id: habit.id)?.id, habit.id)
    }

    func testRepeatedRefreshUsesCacheAndForcedRefreshRetriesItemsFailure() {
        let spy = HabitHomeSpy()
        let vm = model(spy)
        vm.refreshFilteredHabits()
        XCTAssertEqual(spy.itemDates.count, 1)
        spy.itemsError = HabitPresentationError.unavailable
        vm.refreshFilteredHabits(force: true)
        XCTAssertTrue(vm.filteredHabits.isEmpty)
        spy.itemsError = nil
        vm.refreshFilteredHabits(force: true)
        XCTAssertEqual(spy.itemDates.count, 3)
    }

    func testSelectedDateIsNormalizedForQueryAndTodayCanBeRestored() {
        let spy = HabitHomeSpy()
        let vm = model(spy)
        let date = HabitTestSupport.date(2024, 1, 1).addingTimeInterval(43200)
        vm.changeSelectedDate(date)
        XCTAssertEqual(vm.selectedDate, date)
        XCTAssertEqual(spy.itemDates.last, vm.calendar.startOfDay(for: date))
        vm.backToday()
        XCTAssertTrue(vm.calendar.isDateInToday(vm.selectedDate))
    }

    func testProgressCacheInvalidatesAfterReloadAndCalendarChange() {
        let spy = HabitHomeSpy()
        let habit = HabitTestSupport.makeHabit()
        spy.habits = [habit]
        let preferences = CalendarPreferences()
        let vm = model(spy, preferences: preferences)
        let dates = [HabitTestSupport.date(2024, 1, 1)]
        _ = vm.weekDaySummaries(for: dates)
        _ = vm.weekDaySummaries(for: dates)
        XCTAssertEqual(spy.progressCount, 1)
        XCTAssertEqual(spy.progressHabitIDs, [habit.id])
        vm.fetchHabits()
        _ = vm.weekDaySummaries(for: dates)
        XCTAssertEqual(spy.progressCount, 2)
        preferences.update(weekStartsOnMonday: false)
        _ = vm.weekDaySummaries(for: dates)
        XCTAssertEqual(spy.progressCount, 3)
        XCTAssertEqual(spy.progressCalendars.last?.firstWeekday, 1)
    }

    func testCachedProgressRemapsSelectedDateWithoutRequery() throws {
        let spy = HabitHomeSpy()
        let date = HabitTestSupport.date(2024, 1, 1)
        spy.progress = [HabitDayProgress(date: date, isComplete: false, completionRatio: 0.4)]
        let vm = model(spy)
        _ = vm.weekDaySummaries(for: [date])
        vm.changeSelectedDate(date)
        let summary = try XCTUnwrap(vm.weekDaySummaries(for: [date]).first)
        XCTAssertEqual(spy.progressCount, 1)
        XCTAssertTrue(summary.isSelected)
        XCTAssertFalse(summary.isToday)
        XCTAssertFalse(summary.isComplete)
        XCTAssertEqual(summary.completionRatio, 0.4)
    }

    func testEntryChangeResultsOnlyReloadOnUpdated() {
        let spy = HabitHomeSpy()
        let vm = model(spy)
        vm.performEntryChange { .unchanged }
        vm.performEntryChange { .rejected }
        vm.performEntryChange { throw HabitPresentationError.unavailable }
        XCTAssertEqual(spy.fetchCount, 1)
        vm.performEntryChange { .updated }
        XCTAssertEqual(spy.fetchCount, 2)
    }

    func testEntryActionsForwardSelectedDateCountAndNote() {
        let spy = HabitHomeSpy()
        let habit = HabitTestSupport.makeHabit()
        let vm = model(spy)
        let date = HabitTestSupport.date(2024, 1, 1)
        vm.changeSelectedDate(date)
        vm.updateHabitEntry(habit, completedCount: 7, note: "Evening")
        vm.skipHabitEntry(habit)
        vm.resetHabitEntry(habit)
        XCTAssertEqual(spy.entries.map(\.kind), ["update", "skip", "reset"])
        XCTAssertEqual(spy.entries.map(\.id), [habit.id, habit.id, habit.id])
        XCTAssertEqual(spy.entries.map(\.date), [date, date, date])
        XCTAssertEqual(spy.entries.first?.count, 7)
        XCTAssertEqual(spy.entries.first?.note, "Evening")
    }

    func testNotificationReschedulingUsesLatestLoadedSnapshots() {
        let spy = HabitHomeSpy()
        let first = HabitTestSupport.makeHabit()
        let second = HabitTestSupport.makeHabit()
        spy.habits = [first]
        let vm = model(spy)
        spy.habits = [second]
        vm.fetchHabits()
        vm.rescheduleHabitNotifications()
        XCTAssertEqual(spy.scheduledIDs, [second.id])
    }

    func testItemRefreshReplacesRowsAndFailureDoesNotLeaveStaleRows() {
        let spy = HabitHomeSpy()
        let row = HabitListItem(
            id: UUID(), name: "Read", icon: "book", colorHex: "#123456",
            goalType: .count, goalCount: 5, goalUnit: "pages", completedCount: 2,
            completionRatio: 0.4, isSkipped: false, currentStreak: 1,
            longestStreak: 2, lastCompletedDate: nil, canEditEntry: true,
            canResetEntry: true, entryIsCompleted: false
        )
        spy.items = [row]
        let vm = model(spy)
        XCTAssertEqual(vm.filteredHabits, [row])
        spy.itemsError = HabitPresentationError.unavailable
        vm.refreshFilteredHabits(force: true)
        XCTAssertTrue(vm.filteredHabits.isEmpty)
        spy.itemsError = nil
        vm.refreshFilteredHabits(force: true)
        XCTAssertEqual(vm.filteredHabits, [row])
        spy.items = []
        vm.fetchHabits()
        XCTAssertTrue(vm.filteredHabits.isEmpty)
    }

}
