import XCTest

@MainActor
final class HabitStatisticsUITests: HabitUITestCase {
    func testEmptyStatisticsInBothModes() {
        statistics()
        XCTAssertTrue(app.staticTexts.matching(NSPredicate(format:
            "label CONTAINS 'Create a habit to view combined statistics.'")).firstMatch.exists)
        XCTAssertFalse(app.buttons["habit.statistics.previous"].isEnabled)
        XCTAssertFalse(app.buttons["habit.statistics.next"].isEnabled)
        selectStatisticsMode("By Habit")
        XCTAssertTrue(app.staticTexts.matching(NSPredicate(format:
            "label CONTAINS 'Create a habit to view statistics.'")).firstMatch.exists)
    }

    func testOverviewSupportsWeekMonthAndYear() {
        createHabit(todo: true)
        progress()
        statistics()
        XCTAssertTrue(app.staticTexts["All habits"].exists)
        XCTAssertTrue(app.staticTexts["Completed days"].exists)
        for (scope, title) in [("Week", "Week Progress"), ("Month", "Month Progress"),
                                ("Year", "Year Progress")] {
            app.buttons[scope].tap()
            XCTAssertTrue(app.staticTexts[title].waitForExistence(timeout: 5))
        }
        XCTAssertFalse(app.buttons["habit.statistics.next"].isEnabled)
    }

    func testByHabitModeAndCompactToggle() {
        createHabit(todo: true)
        progress()
        statistics(byHabit: true)
        XCTAssertTrue(app.staticTexts["Read daily"].waitForExistence(timeout: 5))
        let toggle = app.buttons["habit.statistics.compact"]
        let original = toggle.value as? String
        toggle.tap()
        XCTAssertNotEqual(toggle.value as? String, original)
        toggle.tap()
        XCTAssertEqual(toggle.value as? String, original)
        for scope in ["Week", "Year", "Month"] {
            app.buttons[scope].tap()
            XCTAssertTrue(app.staticTexts["Read daily"].exists)
        }
    }
    func testOverviewReflectsPartialProgressAndSkip() {
        createHabit()
        progress()
        submitCount("2")
        statistics()
        let count = app.staticTexts["habit.statistics.completedCount"]
        XCTAssertTrue(count.label.hasPrefix("2/"))
        XCTAssertTrue(app.staticTexts["habit.statistics.completedDays"].label.hasPrefix("0/"))
        XCTAssertEqual(app.staticTexts["habit.statistics.skippedDays"].label, "0")
        back()
        swipeEntry("skip")
        statistics()
        XCTAssertEqual(app.staticTexts["habit.statistics.skippedDays"].label, "1")
        back()
        swipeEntry("reset")
        statistics()
        XCTAssertEqual(app.staticTexts["habit.statistics.skippedDays"].label, "0")
        XCTAssertTrue(count.label.hasPrefix("0/"))
    }

}
