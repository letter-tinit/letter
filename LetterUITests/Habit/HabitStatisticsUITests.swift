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

    func testPeriodNavigationChangesValuesAndStopsAtBoundaries() {
        createHabit(startOffset: -400)
        selectDay(offset: -7)
        progress()
        submitCount("2")
        returnToToday()
        statistics()
        app.buttons["Week"].tap()
        let title = app.staticTexts["habit.statistics.period"]
        let original = title.label
        XCTAssertTrue(app.staticTexts["habit.statistics.completedCount"].label.hasPrefix("0/"))
        let previous = app.buttons["habit.statistics.previous"]
        let next = app.buttons["habit.statistics.next"]
        XCTAssertTrue(previous.isEnabled)
        XCTAssertFalse(next.isEnabled)
        previous.tap()
        XCTAssertNotEqual(title.label, original)
        XCTAssertTrue(app.staticTexts["habit.statistics.completedCount"].label.hasPrefix("2/"))
        XCTAssertTrue(next.isEnabled)
        next.tap()
        XCTAssertEqual(title.label, original)
        for scope in ["Month", "Year"] {
            app.buttons[scope].tap()
            XCTAssertTrue(previous.isEnabled)
            XCTAssertFalse(next.isEnabled)
            var attempts = 0
            while previous.isEnabled && attempts < 16 {
                previous.tap()
                attempts += 1
            }
            XCTAssertFalse(previous.isEnabled)
            XCTAssertTrue(next.isEnabled)
            selectStatisticsMode("By Habit")
            XCTAssertTrue(app.staticTexts["Read daily"].exists)
            selectStatisticsMode("Overview")
        }
    }

    func testCompactPreferenceSurvivesRelaunch() {
        createHabit(todo: true)
        statistics(byHabit: true)
        let toggle = app.buttons["habit.statistics.compact"]
        toggle.tap()
        let expected = toggle.value as? String
        app.terminate()
        app.launch()
        XCTAssertTrue(app.buttons["habit.statistics"].waitForExistence(timeout: 10))
        statistics(byHabit: true)
        XCTAssertEqual(toggle.value as? String, expected)
    }

    func testFutureHabitShowsNoRecordsUntilItsPeriod() {
        createHabit(startOffset: 7)
        statistics(byHabit: true)
        app.buttons["Week"].tap()
        XCTAssertFalse(app.staticTexts["Read daily"].exists)
        XCTAssertFalse(app.buttons["habit.statistics.previous"].isEnabled)
        XCTAssertFalse(app.buttons["habit.statistics.next"].isEnabled)
        XCTAssertTrue(app.staticTexts["No habit records"].exists)
        selectStatisticsMode("Overview")
        XCTAssertFalse(app.staticTexts["habit.statistics.completedCount"].exists)
    }

}
