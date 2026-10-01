import XCTest

@MainActor
final class HabitLifecycleUITests: HabitUITestCase {
    func testCancelDeletePreservesHabit() {
        createHabit()
        openDetail()
        detailAction("Delete")
        cancelConfirmation("Delete habit?")
        XCTAssertTrue(app.buttons["habit.detail.menu"].exists)
        back()
        XCTAssertTrue(app.staticTexts["Read daily"].exists)
    }

    func testDeleteRemovesHabitAndStatisticsHistory() {
        createHabit(todo: true)
        progress()
        openDetail()
        detailAction("Delete")
        app.buttons["Delete Habit"].tap()
        XCTAssertTrue(app.buttons["habit.add"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.staticTexts["Read daily"].exists)
        statistics(byHabit: true)
        XCTAssertFalse(app.staticTexts["Read daily"].exists)
        app.terminate()
        app.launch()
        XCTAssertTrue(app.buttons["habit.add"].waitForExistence(timeout: 10))
        XCTAssertFalse(app.staticTexts["Read daily"].exists)
    }

    func testCancelCompletionPreservesActiveHabit() {
        createHabit()
        openDetail()
        detailAction("Complete Habit")
        cancelConfirmation("Complete habit?")
        back()
        XCTAssertTrue(app.buttons["habit.progress.Read daily"].exists)
    }

    func testCompleteHabitKeepsHistoryAndDisablesTracking() {
        createHabit(todo: true)
        progress()
        openDetail()
        detailAction("Complete Habit")
        app.buttons["Complete Habit"].tap()
        XCTAssertTrue(app.buttons["habit.add"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["Read daily"].exists)
        XCTAssertFalse(app.buttons["habit.progress.Read daily"].exists)
        openDetail()
        XCTAssertTrue(app.staticTexts["habit.detail.completed"].exists)
        app.buttons["habit.detail.menu"].tap()
        XCTAssertFalse(app.buttons["Edit"].exists)
        XCTAssertFalse(app.buttons["Complete Habit"].exists)
        app.tap()
        back()
        statistics(byHabit: true)
        XCTAssertTrue(app.staticTexts["Read daily"].waitForExistence(timeout: 5))
    }
    func testResettingCompletedHabitRestoresTrackingAndEditAction() {
        createHabit(todo: true)
        openDetail()
        detailAction("Complete Habit")
        app.buttons["Complete Habit"].tap()
        XCTAssertTrue(app.buttons["habit.add"].waitForExistence(timeout: 5))
        assertStatus("1/1")
        swipeEntry("reset")
        assertStatus("0/1")
        XCTAssertTrue(app.buttons["habit.progress.Read daily"].isEnabled)
        openDetail()
        app.buttons["habit.detail.menu"].tap()
        XCTAssertTrue(app.buttons["Edit"].exists)
        XCTAssertTrue(app.buttons["Complete Habit"].exists)
    }

}
