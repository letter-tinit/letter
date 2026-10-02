import XCTest
@testable import Domain
@testable import Presentation
import Utility

@MainActor
final class HabitDetailViewModelTests: XCTestCase {
    func testLoadMapsSnapshotAndRequestsCorrectIdentity() {
        let spy = HabitDetailSpy()
        let habit = HabitTestSupport.makeHabit(completedAt: HabitTestSupport.date(2024, 2, 1), goalCount: 7, currentStreak: 3, longestStreak: 5)
        spy.habit = habit
        let vm = HabitDetailViewModel(habitID: habit.id, useCase: spy)
        vm.load()
        XCTAssertEqual(spy.loadedIDs, [habit.id])
        XCTAssertEqual(vm.habit?.id, habit.id)
        XCTAssertEqual(vm.name, habit.name)
        XCTAssertEqual(vm.icon, habit.icon)
        XCTAssertEqual(vm.colorHex, habit.colorHex)
        XCTAssertEqual(vm.goalTitle, "7 pages")
        XCTAssertEqual(vm.currentStreak, 3)
        XCTAssertEqual(vm.longestStreak, 5)
        XCTAssertTrue(vm.isCompleted)
        XCTAssertNil(vm.errorMessage)
    }

    func testMissingHabitClearsPreviouslyLoadedState() {
        let spy = HabitDetailSpy()
        let habit = HabitTestSupport.makeHabit()
        spy.habit = habit
        let vm = HabitDetailViewModel(habitID: habit.id, useCase: spy)
        vm.load()
        spy.habit = nil
        vm.load()
        XCTAssertNil(vm.habit)
        XCTAssertEqual(vm.name, "")
        XCTAssertEqual(vm.currentStreak, 0)
        XCTAssertFalse(vm.isCompleted)
    }

    func testLoadFailureClearsSnapshotAndSuccessfulRetryClearsError() {
        let spy = HabitDetailSpy()
        let habit = HabitTestSupport.makeHabit()
        spy.habit = habit
        let vm = HabitDetailViewModel(habitID: habit.id, useCase: spy)
        vm.load()
        spy.error = HabitPresentationError.unavailable
        vm.load()
        XCTAssertNil(vm.habit)
        XCTAssertEqual(vm.errorMessage, "Habit service unavailable")
        spy.error = nil
        vm.load()
        XCTAssertEqual(vm.habit?.id, habit.id)
        XCTAssertNil(vm.errorMessage)
    }

    func testDeleteFailureAndRetryReturnExplicitOutcome() {
        let spy = HabitDetailSpy()
        let id = UUID()
        let vm = HabitDetailViewModel(habitID: id, useCase: spy)
        spy.error = HabitPresentationError.unavailable
        XCTAssertFalse(vm.delete())
        XCTAssertEqual(vm.errorMessage, "Habit service unavailable")
        spy.error = nil
        XCTAssertTrue(vm.delete())
        XCTAssertNil(vm.errorMessage)
        XCTAssertEqual(spy.deletedIDs, [id, id])
    }

    func testCompletionFailureAndRetryForwardIdentityAndDate() {
        let spy = HabitDetailSpy()
        let id = UUID()
        let date = HabitTestSupport.date(2024, 2, 1)
        let vm = HabitDetailViewModel(habitID: id, useCase: spy)
        spy.error = HabitPresentationError.unavailable
        XCTAssertFalse(vm.complete(now: date))
        XCTAssertNotNil(vm.errorMessage)
        spy.error = nil
        XCTAssertTrue(vm.complete(now: date))
        XCTAssertNil(vm.errorMessage)
        XCTAssertEqual(spy.completions.map(\.id), [id, id])
        XCTAssertEqual(spy.completions.map(\.date), [date, date])
    }

    func testReminderTitleSortsEnabledTimesAndExcludesDisabledOnes() {
        let calendar = Calendar.current
        let day = HabitTestSupport.date(2024, 1, 1)
        let early = calendar.date(bySettingHour: 8, minute: 15, second: 0, of: day)!
        let late = calendar.date(bySettingHour: 20, minute: 30, second: 0, of: day)!
        let spy = HabitDetailSpy()
        spy.habit = HabitPresentationSupport.habit(reminders: [
            HabitReminderConfiguration(time: late),
            HabitReminderConfiguration(time: day, isEnabled: false),
            HabitReminderConfiguration(time: early)
        ])
        let vm = HabitDetailViewModel(habitID: spy.habit!.id, useCase: spy)
        vm.load()
        XCTAssertEqual(vm.reminderTitle, "08:15, 20:30")
        XCTAssertEqual(vm.habitDescription, "Evening reading")
    }

    func testTodoGoalAndDisabledRemindersMapToLocalizedTitles() {
        let spy = HabitDetailSpy()
        spy.habit = HabitPresentationSupport.habit(goalType: .todo, reminders: [
            HabitReminderConfiguration(time: HabitTestSupport.date(2024, 1, 1), isEnabled: false)
        ])
        let vm = HabitDetailViewModel(habitID: spy.habit!.id, useCase: spy)
        vm.load()
        XCTAssertEqual(vm.goalTitle, "habit.goal.completeOnce".localized)
        XCTAssertEqual(vm.reminderTitle, "habit.common.none".localized)
        XCTAssertEqual(vm.completedTitle, "habit.common.none".localized)
    }

}
