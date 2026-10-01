import XCTest

@MainActor
final class HabitHomeUITests: HabitUITestCase {
    func testEmptyHomeAndNavigationBackFromStatistics() {
        XCTAssertTrue(app.staticTexts["No Habits"].exists)
        XCTAssertEqual(app.staticTexts.matching(NSPredicate(format: "identifier BEGINSWITH 'habit.status.'")).count, 0)
        XCTAssertTrue(app.buttons["habit.add"].isEnabled)
        statistics()
        back()
        XCTAssertTrue(app.buttons["habit.add"].isHittable)
    }

    func testPastDayProgressIsIndependentFromToday() {
        createHabit(startOffset: -7)
        selectDay(offset: -1)
        progress()
        submitCount("3")
        assertStatus("3/5 pages")
        returnToToday()
        assertStatus("0/5 pages")
        selectDay(offset: -1)
        assertStatus("3/5 pages")
        openDetail()
        XCTAssertEqual(app.staticTexts["habit.detail.goal"].label, "5 pages")
        XCTAssertEqual(app.staticTexts["habit.detail.currentStreak"].label, "0")
        back()
        XCTAssertEqual(app.buttons["habit.day.\(dateID(Calendar.current.date(byAdding: .day, value: -1, to: Date())!))"].firstMatch.value as? String, "selected")
    }

    func testReturningFromAnotherTabPreservesHabitProgress() {
        createHabit(startOffset: -7)
        progress()
        submitCount("1")
        app.tabBars.buttons["Profile"].tap()
        app.tabBars.buttons["Habits"].tap()
        assertStatus("1/5 pages")
    }

    func testDetailStreakUpdatesAfterCompletionAndReset() {
        createHabit(startOffset: -7)
        progress()
        app.buttons["habit.entry.completeGoal"].tap()
        openDetail()
        XCTAssertEqual(app.staticTexts["habit.detail.currentStreak"].label, "1")
        XCTAssertEqual(app.staticTexts["habit.detail.bestStreak"].label, "1")
        XCTAssertEqual(app.staticTexts["habit.detail.repeat"].label, "Daily")
        XCTAssertEqual(app.staticTexts["habit.detail.reminder"].label, "None")
        back()
        swipeEntry("reset")
        openDetail()
        XCTAssertEqual(app.staticTexts["habit.detail.currentStreak"].label, "0")
    }

    func testEndDateHidesHabitAfterDurationButKeepsPastTracking() {
        createHabit(startOffset: -7, endOffset: -1)
        XCTAssertFalse(app.staticTexts["Read daily"].exists)
        selectDay(offset: -1)
        assertStatus("0/5 pages")
        progress()
        submitCount("2")
        assertStatus("2/5 pages")
        returnToToday()
        XCTAssertFalse(app.staticTexts["Read daily"].exists)
        statistics(byHabit: true)
        XCTAssertTrue(app.staticTexts["Read daily"].exists)
    }
}
