import XCTest
@testable import Domain
@testable import Presentation

@MainActor
final class CreateHabitViewModelTests: XCTestCase {
    private func model(_ spy: HabitFormSpy, mode: HabitFormMode = .create, source: HabitSnapshot? = nil) -> CreateHabitViewModel {
        CreateHabitViewModel(mode: mode, source: source, formUseCase: spy, calendarPreferences: CalendarPreferences())
    }

    func testInvalidCountInputsNeverSubmit() {
        let spy = HabitFormSpy()
        let vm = model(spy)
        vm.name = "Read"
        for text in ["", "abc", "0", "-1", "1.5", String(repeating: "9", count: 100)] {
            vm.goalCountText = text
            XCTAssertFalse(vm.canSave, text)
            XCTAssertNil(vm.save(), text)
        }
        XCTAssertTrue(spy.submissions.isEmpty)
    }

    func testWhitespaceNameAndUnitCannotSubmit() {
        let spy = HabitFormSpy()
        let vm = model(spy)
        vm.name = " \n "
        XCTAssertNil(vm.save())
        vm.name = "Read"
        vm.goalUnit = " \n "
        XCTAssertNil(vm.save())
        XCTAssertTrue(spy.submissions.isEmpty)
    }

    func testCustomScheduleAndDateBoundsPreventSubmission() {
        let spy = HabitFormSpy()
        let vm = model(spy)
        vm.name = "Read"
        vm.frequency = .custom
        vm.selectedDays = []
        XCTAssertNil(vm.save())
        vm.selectedDays = [1]
        vm.startDate = HabitTestSupport.date(2024, 1, 2)
        vm.endDate = HabitTestSupport.date(2024, 1, 1)
        vm.hasEndDate = true
        XCTAssertNil(vm.save())
        vm.endDate = vm.startDate
        XCTAssertTrue(vm.canSave)
        XCTAssertTrue(spy.submissions.isEmpty)
    }

    func testSaveSubmitsTrimmedNormalizedDraftAndEditIdentity() throws {
        let spy = HabitFormSpy()
        let id = UUID()
        let vm = model(spy, mode: .edit(id))
        vm.name = "  Read\n"
        vm.habitDescription = "  Every evening \n"
        vm.goalUnit = " pages "
        vm.goalCountText = "7"
        vm.frequency = .custom
        vm.selectedDays = [6, 1, 3]
        vm.startDate = HabitTestSupport.date(2024, 1, 1).addingTimeInterval(43200)
        vm.hasEndDate = true
        vm.endDate = HabitTestSupport.date(2024, 1, 3).addingTimeInterval(43200)
        vm.icon = "book.fill"
        vm.colorHex = "#123456"
        XCTAssertEqual(vm.save(), spy.savedID)
        XCTAssertEqual(spy.submissions.count, 1)
        let submission = try XCTUnwrap(spy.submissions.first)
        XCTAssertEqual(submission.mode, .edit(id))
        XCTAssertEqual(submission.draft.name, "Read")
        XCTAssertEqual(submission.draft.description, "Every evening")
        XCTAssertEqual(submission.draft.goalUnit, "pages")
        XCTAssertEqual(submission.draft.goalCount, 7)
        XCTAssertEqual(submission.draft.targetDaysOfWeek, [1, 3, 6])
        XCTAssertEqual(submission.draft.startDate, submission.calendar.startOfDay(for: vm.startDate))
        XCTAssertEqual(submission.draft.endDate, submission.calendar.startOfDay(for: vm.endDate))
        XCTAssertEqual(submission.draft.icon, "book.fill")
        XCTAssertEqual(submission.draft.colorHex, "#123456")
    }

    func testTodoSubmitsOneStepAndDisabledEndDateIsOmitted() throws {
        let spy = HabitFormSpy()
        let vm = model(spy)
        vm.name = "Walk"
        vm.goalType = .todo
        vm.goalCountText = "invalid"
        XCTAssertEqual(vm.save(), spy.savedID)
        let submission = try XCTUnwrap(spy.submissions.first)
        XCTAssertEqual(submission.mode, .create)
        XCTAssertEqual(submission.draft.goalType, .todo)
        XCTAssertEqual(submission.draft.goalCount, 1)
        XCTAssertNil(submission.draft.endDate)
    }

    func testSaveFailurePreservesInputAndRetryClearsError() {
        let spy = HabitFormSpy()
        let vm = model(spy)
        vm.name = "Read"
        spy.error = HabitPresentationError.unavailable
        XCTAssertNil(vm.save())
        XCTAssertEqual(vm.errorMessage, "Habit service unavailable")
        XCTAssertEqual(vm.name, "Read")
        spy.error = nil
        XCTAssertEqual(vm.save(), spy.savedID)
        XCTAssertNil(vm.errorMessage)
        XCTAssertEqual(spy.submissions.count, 2)
    }

    func testEditInitializesSavedFields() {
        let habit = HabitTestSupport.makeHabit(endDate: HabitTestSupport.date(2024, 2, 1), frequency: .custom, targetDaysOfWeek: [1, 3], goalCount: 9)
        let vm = model(HabitFormSpy(), mode: .edit(habit.id), source: habit)
        XCTAssertTrue(vm.isEditing)
        XCTAssertEqual(vm.name, habit.name)
        XCTAssertEqual(vm.icon, habit.icon)
        XCTAssertEqual(vm.colorHex, habit.colorHex)
        XCTAssertEqual(vm.startDate, habit.effectiveStartDate)
        XCTAssertTrue(vm.hasEndDate)
        XCTAssertEqual(vm.endDate, habit.endDate)
        XCTAssertEqual(vm.frequency, .custom)
        XCTAssertEqual(vm.selectedDays, [1, 3])
        XCTAssertEqual(vm.goalCountText, "9")
        XCTAssertEqual(vm.goalUnit, "pages")
    }

    func testWeekdayTogglesSynchronizePresets() {
        let vm = model(HabitFormSpy())
        vm.selectFrequency(.weekday)
        XCTAssertEqual(vm.selectedDays, Set(1...5))
        vm.toggleWeekday(1)
        XCTAssertEqual(vm.frequency, .custom)
        vm.toggleWeekday(1)
        XCTAssertEqual(vm.frequency, .weekday)
        vm.toggleWeekday(0)
        vm.toggleWeekday(6)
        XCTAssertEqual(vm.frequency, .daily)
        vm.selectFrequency(.weekend)
        XCTAssertEqual(vm.selectedDays, [0, 6])
        vm.toggleWeekday(0)
        vm.toggleWeekday(0)
        XCTAssertEqual(vm.frequency, .weekend)
    }

    func testReminderDeletionAndSubmissionPreserveConfiguration() throws {
        let spy = HabitFormSpy()
        let vm = model(spy)
        vm.name = "Read"
        let kept = HabitReminderConfiguration(time: HabitTestSupport.date(2024, 1, 1), daysOfWeek: [1, 3], isEnabled: false)
        let removed = HabitReminderConfiguration(time: HabitTestSupport.date(2024, 1, 2))
        vm.reminders = [kept, removed]
        vm.deleteReminder(id: removed.id)
        XCTAssertEqual(vm.save(), spy.savedID)
        let reminder = try XCTUnwrap(spy.submissions.first?.draft.reminders.first)
        XCTAssertEqual(vm.reminders.count, 1)
        XCTAssertEqual(reminder.id, kept.id)
        XCTAssertEqual(reminder.notificationID, kept.notificationID)
        XCTAssertEqual(reminder.daysOfWeek, [1, 3])
        XCTAssertFalse(reminder.isEnabled)
    }

    func testEditSortsRemindersWithoutLosingIdentityOrEnabledState() {
        let early = HabitReminderConfiguration(time: HabitTestSupport.date(2024, 1, 1), daysOfWeek: [1], isEnabled: false)
        let late = HabitReminderConfiguration(time: HabitTestSupport.date(2024, 1, 2))
        let habit = HabitPresentationSupport.habit(reminders: [late, early])
        let vm = model(HabitFormSpy(), mode: .edit(habit.id), source: habit)
        XCTAssertEqual(vm.reminders.map(\.id), [early.id, late.id])
        XCTAssertEqual(vm.reminders.first?.notificationID, early.notificationID)
        XCTAssertEqual(vm.reminders.first?.daysOfWeek, [1])
        XCTAssertEqual(vm.reminders.first?.isEnabled, false)
    }

    func testAddingReminderUsesNineAMAndKeepsTimeOrder() throws {
        let vm = model(HabitFormSpy())
        vm.reminders = [HabitReminderConfiguration(time: .distantFuture)]
        vm.addReminder()
        let reminder = try XCTUnwrap(vm.reminders.first)
        let components = CalendarPreferences().calendar.dateComponents([.hour, .minute], from: reminder.time)
        XCTAssertEqual(vm.reminders.count, 2)
        XCTAssertEqual(components.hour, 9)
        XCTAssertEqual(components.minute, 0)
        XCTAssertTrue(reminder.isEnabled)
        XCTAssertTrue(vm.reminders[0].time < vm.reminders[1].time)
    }

}
