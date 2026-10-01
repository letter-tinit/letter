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
        XCTAssertTrue(app.buttons["habit.add"].exists)
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
        progress("Read daily")
        assertStatus("1/1", name: "Read daily")
        assertStatus("0/1", name: "Walk daily")
        XCTAssertTrue(app.buttons["habit.progress.Walk daily"].exists)
    }

}
