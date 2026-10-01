import XCTest

@MainActor
final class HabitFormUITests: HabitUITestCase {
    func testEmptyNameAndWhitespaceCannotBeSaved() {
        openForm()
        XCTAssertFalse(app.buttons["habit.form.save"].isEnabled)
        replace("habit.form.name", with: "   ")
        XCTAssertFalse(app.buttons["habit.form.save"].isEnabled)
        replace("habit.form.name", with: "Read daily")
        XCTAssertTrue(app.buttons["habit.form.save"].isEnabled)
    }

    func testCountGoalRequiresPositiveTargetAndUnit() {
        openForm()
        replace("habit.form.name", with: "Read daily")
        replace("habit.form.target", with: "0")
        XCTAssertFalse(app.buttons["habit.form.save"].isEnabled)
        replace("habit.form.target", with: "5")
        replace("habit.form.unit", with: " ")
        XCTAssertFalse(app.buttons["habit.form.save"].isEnabled)
        replace("habit.form.unit", with: "pages")
        XCTAssertTrue(app.buttons["habit.form.save"].isEnabled)
    }

    func testCreateCountHabitAndReadDetails() {
        openForm()
        replace("habit.form.name", with: " Read daily ")
        replace("habit.form.description", with: "Read a book")
        replace("habit.form.target", with: "5")
        replace("habit.form.unit", with: "pages")
        saveForm()
        assertStatus("0/5 pages")
        openDetail()
        XCTAssertTrue(app.staticTexts["Read a book"].exists)
        XCTAssertTrue(app.staticTexts["Daily"].exists)
        XCTAssertTrue(app.staticTexts["Current streak"].exists)
        XCTAssertTrue(app.staticTexts["Best streak"].exists)
    }

    func testTodoHidesCountFieldsAndCreatesOneStepGoal() {
        createHabit(todo: true)
        assertStatus("0/1")
        openDetail()
        detailAction("Edit")
        XCTAssertFalse(app.textFields["habit.form.target"].exists)
        XCTAssertFalse(app.textFields["habit.form.unit"].exists)
    }

    func testCancelCreationLeavesListEmpty() {
        openForm()
        replace("habit.form.name", with: "Unsaved habit")
        back()
        XCTAssertFalse(app.staticTexts["Unsaved habit"].exists)
        XCTAssertTrue(app.buttons["habit.add"].exists)
    }

    func testEditHabitUpdatesListAndDetails() {
        createHabit()
        openDetail()
        detailAction("Edit")
        replace("habit.form.name", with: "Read books")
        replace("habit.form.description", with: "Updated description")
        saveForm()
        XCTAssertTrue(app.staticTexts["Read books"].exists)
        XCTAssertTrue(app.staticTexts["Updated description"].exists)
        back()
        XCTAssertFalse(app.staticTexts["Read daily"].exists)
        assertStatus("0/5 pages", name: "Read books")
    }

    func testFrequencyPresetsAndCustomDayValidation() {
        openForm()
        replace("habit.form.name", with: "Schedule")
        reveal(app.buttons["Weekday"])
        app.buttons["Weekday"].tap()
        for day in 0...6 {
            XCTAssertEqual(app.buttons["habit.form.weekday.\(day)"].value as? String,
                           (1...5).contains(day) ? "selected" : "unselected")
        }
        app.buttons["Weekend"].tap()
        for day in 0...6 {
            XCTAssertEqual(app.buttons["habit.form.weekday.\(day)"].value as? String,
                           [0, 6].contains(day) ? "selected" : "unselected")
        }
        app.buttons["habit.form.weekday.0"].tap()
        app.buttons["habit.form.weekday.6"].tap()
        XCTAssertFalse(app.buttons["habit.form.save"].isEnabled)
        app.buttons["habit.form.weekday.1"].tap()
        XCTAssertTrue(app.buttons["habit.form.save"].isEnabled)
        app.buttons["Daily"].tap()
        saveForm()
        openDetail("Schedule")
        XCTAssertTrue(app.staticTexts["Daily"].exists)
    }

    func testReminderCanBeAddedRemovedAndRetainedWhenEditing() {
        openForm()
        replace("habit.form.name", with: "Reminder")
        reveal(app.buttons["habit.reminder.add"])
        app.buttons["habit.reminder.add"].tap()
        XCTAssertEqual(app.buttons.matching(identifier: "habit.reminder.delete").count, 1)
        app.buttons["habit.reminder.delete"].tap()
        XCTAssertEqual(app.buttons.matching(identifier: "habit.reminder.delete").count, 0)
        app.buttons["habit.reminder.add"].tap()
        saveForm()
        openDetail("Reminder")
        detailAction("Edit")
        reveal(app.buttons["habit.reminder.delete"])
        XCTAssertEqual(app.buttons.matching(identifier: "habit.reminder.delete").count, 1)
    }

    func testEndDateCanBeSetAndCleared() {
        openForm()
        replace("habit.form.name", with: "Duration")
        reveal(app.buttons["habit.form.endDate"])
        XCTAssertTrue(app.buttons["habit.form.endDate"].label.contains("No End"))
        app.buttons["habit.form.endDate"].tap()
        app.buttons["Done"].tap()
        XCTAssertFalse(app.buttons["habit.form.endDate"].label.contains("No End"))
        app.buttons["habit.form.endDate"].tap()
        app.buttons["Reset"].tap()
        XCTAssertTrue(app.buttons["habit.form.endDate"].label.contains("No End"))
    }

    func testStartDatePickerCancellationPreservesDate() {
        openForm()
        let button = app.buttons["habit.form.startDate"]
        reveal(button)
        let original = button.label
        button.tap()
        app.buttons["Cancel"].tap()
        XCTAssertEqual(button.label, original)
    }

    func testSymbolAndColorSelectionsSurviveSaveAndEdit() {
        openForm()
        replace("habit.form.name", with: "Styled")
        app.buttons["habit.form.icon"].tap()
        app.buttons["flame.fill"].tap()
        XCTAssertEqual(app.buttons["habit.form.icon"].value as? String, "flame.fill")
        let color = app.buttons["habit.form.color.#FF6B6B"]
        reveal(color)
        color.tap()
        XCTAssertEqual(color.value as? String, "selected")
        saveForm()
        openDetail("Styled")
        detailAction("Edit")
        XCTAssertEqual(app.buttons["habit.form.icon"].value as? String, "flame.fill")
        reveal(color)
        XCTAssertEqual(color.value as? String, "selected")
    }
    func testSwitchingGoalTypesRestoresCountInputs() {
        openForm()
        replace("habit.form.name", with: "Goal type")
        reveal(app.buttons["Todo"])
        app.buttons["Todo"].tap()
        XCTAssertFalse(app.textFields["habit.form.target"].exists)
        app.buttons["Count"].tap()
        XCTAssertTrue(app.textFields["habit.form.target"].exists)
        XCTAssertEqual(app.textFields["habit.form.target"].value as? String, "1")
        XCTAssertTrue(app.buttons["habit.form.save"].isEnabled)
    }

    func testCancelEditingPreservesSavedValues() {
        createHabit()
        openDetail()
        detailAction("Edit")
        replace("habit.form.name", with: "Unsaved edit")
        // Edit is presented as a sheet; dismiss through its drag gesture.
        let bar = app.navigationBars["Edit Habit"]
        XCTAssertTrue(bar.waitForExistence(timeout: 5))
        bar.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
            .press(forDuration: 0.05, thenDragTo: app.coordinate(
                withNormalizedOffset: CGVector(dx: 0.5, dy: 0.8)
            ))
        XCTAssertTrue(app.buttons["habit.detail.menu"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["Read daily"].exists)
        XCTAssertFalse(app.staticTexts["Unsaved edit"].exists)
        back()
        assertStatus("0/5 pages")
    }

}
