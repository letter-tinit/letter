import XCTest

@MainActor
final class HabitEntryUITests: HabitUITestCase {
    func testTodoCompletionAndReset() {
        createHabit(todo: true)
        progress()
        assertStatus("1/1")
        XCTAssertFalse(app.buttons["habit.progress.Read daily"].exists)
        swipeEntry("reset")
        assertStatus("0/1")
        XCTAssertTrue(app.buttons["habit.progress.Read daily"].exists)
    }

    func testCountProgressAccumulatesAndCanBeReset() {
        createHabit()
        progress()
        submitCount("2")
        assertStatus("2/5 pages")
        progress()
        submitCount("3")
        assertStatus("5/5 pages")
        swipeEntry("reset")
        assertStatus("0/5 pages")
    }

    func testCompleteGoalAddsOnlyRemainingCount() {
        createHabit()
        progress()
        submitCount("2")
        progress()
        app.buttons["habit.entry.completeGoal"].tap()
        assertStatus("5/5 pages")
    }

    func testNumberPadClearBackspaceAndZeroSubmission() {
        createHabit()
        progress()
        app.buttons["9"].tap()
        app.buttons["C"].tap()
        app.buttons["Done"].tap()
        assertStatus("0/5 pages")
        progress()
        app.buttons["2"].tap()
        app.buttons["3"].tap()
        app.buttons["⌫"].tap()
        app.buttons["Done"].tap()
        assertStatus("2/5 pages")
    }

    func testSkipAndReset() {
        createHabit()
        swipeEntry("skip")
        assertStatus("Skipped")
        XCTAssertFalse(app.buttons["habit.progress.Read daily"].exists)
        swipeEntry("reset")
        assertStatus("0/5 pages")
    }

    func testHabitAndProgressPersistAcrossAppRelaunch() {
        createHabit()
        progress()
        submitCount("2")
        app.terminate()
        app.launch()
        XCTAssertTrue(app.staticTexts["Read daily"].waitForExistence(timeout: 10))
        assertStatus("2/5 pages")
    }

    func testWeekNavigationAndReturnToToday() {
        createHabit()
        let today = app.buttons.matching(NSPredicate(format:
            "identifier BEGINSWITH 'habit.day.' AND value == 'selected'")).firstMatch
        let todayID = today.identifier
        swipeWeek(forward: true)
        let changed = XCTNSPredicateExpectation(
            predicate: NSPredicate(format: "value != 'selected'"), object: app.buttons[todayID]
        )
        XCTAssertEqual(XCTWaiter.wait(for: [changed], timeout: 5), .completed)
        returnToToday()
        XCTAssertEqual(app.buttons[todayID].value as? String, "selected")
        assertStatus("0/5 pages")
    }
    func testFutureEntriesCannotBeChanged() {
        createHabit(todo: true)
        swipeWeek(forward: true)
        let button = app.buttons["habit.progress.Read daily"]
        XCTAssertTrue(button.exists)
        XCTAssertFalse(button.isEnabled)
        assertStatus("0/1")
    }

    func testDatesBeforeStartDoNotShowHabit() {
        createHabit()
        swipeWeek(forward: false)
        XCTAssertFalse(app.staticTexts["Read daily"].exists)
        returnToToday()
        XCTAssertTrue(app.staticTexts["Read daily"].exists)
    }

    func testCompletingOneHabitDoesNotChangeAnother() {
        createHabit("Read daily", todo: true)
        createHabit("Walk daily", todo: true)
        XCTAssertLessThan(app.staticTexts["Read daily"].frame.minY, app.staticTexts["Walk daily"].frame.minY)
        progress("Read daily")
        assertStatus("1/1", name: "Read daily")
        assertStatus("0/1", name: "Walk daily")
        XCTAssertTrue(app.buttons["habit.progress.Walk daily"].exists)
        XCTAssertLessThan(app.staticTexts["Walk daily"].frame.minY, app.staticTexts["Read daily"].frame.minY)
    }

    func testNumberPadDismissalDoesNotSubmitProgress() {
        createHabit()
        progress()
        XCTAssertTrue(app.buttons["habit.entry.completeGoal"].waitForExistence(timeout: 5))
        app.buttons["4"].tap()
        app.buttons["habit.entry.completeGoal"].coordinate(withNormalizedOffset: .zero)
            .press(forDuration: 0.05, thenDragTo: app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.95)))
        assertStatus("0/5 pages")
        XCTAssertFalse(app.buttons["habit.entry.completeGoal"].exists)
    }

    func testOverGoalProgressAndFullSwipeReset() {
        createHabit()
        progress()
        submitCount("9")
        assertStatus("9/5 pages")
        let row = app.cells.containing(.staticText, identifier: "Read daily").firstMatch
        row.swipeLeft(velocity: .fast)
        if app.buttons["habit.entry.reset"].exists { app.buttons["habit.entry.reset"].tap() }
        assertStatus("0/5 pages")
    }


    func testFutureSkipCanBePlannedAndReset() {
        createHabit(todo: true)
        swipeWeek(forward: true)
        XCTAssertFalse(app.buttons["habit.progress.Read daily"].isEnabled)
        swipeEntry("skip")
        assertStatus("Skipped")
        swipeEntry("reset")
        assertStatus("0/1")
        XCTAssertFalse(app.buttons["habit.progress.Read daily"].isEnabled)
    }

}
