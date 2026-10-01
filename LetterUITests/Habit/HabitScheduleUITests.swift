import XCTest

@MainActor
final class HabitScheduleUITests: HabitUITestCase {
    func testEndDateCannotPrecedeStartAndMovesWithLaterStart() {
        openForm()
        replace("habit.form.name", with: "Date bounds")
        setFormDate("habit.form.endDate", offset: 1)
        setFormDate("habit.form.startDate", offset: 2)
        let expected = dateID(Calendar.current.date(byAdding: .day, value: 2, to: Date())!)
        XCTAssertEqual(app.buttons["habit.form.endDate"].value as? String, expected)
        app.buttons["habit.form.endDate"].tap()
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US")
        formatter.dateFormat = "EEEE, MMMM d"
        let yesterday = Calendar.current.date(byAdding: .day, value: 1, to: Date())!
        let invalid = app.buttons.matching(NSPredicate(format: "label CONTAINS %@", formatter.string(from: yesterday))).firstMatch
        XCTAssertTrue(invalid.exists)
        XCTAssertFalse(invalid.isEnabled)
        app.buttons["calendar.cancel"].tap()
        XCTAssertTrue(app.buttons["habit.form.save"].isEnabled)
    }

    func testEndDateCancellationPreservesSavedValue() {
        openForm()
        replace("habit.form.name", with: "Cancel date")
        setFormDate("habit.form.endDate", offset: 1)
        let button = app.buttons["habit.form.endDate"]
        let original = button.value as? String
        button.tap()
        chooseCalendarDate(Calendar.current.date(byAdding: .day, value: 2, to: Date())!)
        app.buttons["calendar.cancel"].tap()
        XCTAssertEqual(button.value as? String, original)
    }



    func testWeekdayAndWeekendPresetsSurviveCreation() {
        for preset in ["Weekday", "Weekend"] {
            openForm()
            replace("habit.form.name", with: preset)
            reveal(app.buttons[preset])
            app.buttons[preset].tap()
            saveForm()
            // A preset may exclude today; navigate to a matching date.
            let weekday = Calendar.current.component(.weekday, from: Date()) - 1
            let offset = preset == "Weekday" ? (weekday == 0 ? 1 : weekday == 6 ? 2 : 0) : (weekday == 0 || weekday == 6 ? 0 : 6 - weekday)
            selectDay(offset: offset)
            openDetail(preset)
            XCTAssertEqual(app.staticTexts["habit.detail.repeat"].label, preset == "Weekday" ? "Weekdays" : "Weekends")
            detailAction("Edit")
            reveal(app.buttons["habit.form.weekday.0"])
            for day in 0...6 {
                let selected = preset == "Weekday" ? (1...5).contains(day) : [0, 6].contains(day)
                XCTAssertEqual(app.buttons["habit.form.weekday.\(day)"].value as? String, selected ? "selected" : "unselected")
            }
            saveForm()
            back()
            returnToToday()
        }
    }

    func testStartDateSaveRestrictsTrackingAndSurvivesRelaunch() {
        openForm()
        replace("habit.form.name", with: "Starts later")
        reveal(app.buttons["habit.form.startDate"])
        app.buttons["habit.form.startDate"].tap()
        let target = Calendar.current.date(byAdding: .day, value: 1, to: Date())!
        chooseCalendarDate(target)
        app.buttons["calendar.done"].tap()
        XCTAssertEqual(app.buttons["habit.form.startDate"].value as? String, dateID(target))
        saveForm()
        XCTAssertFalse(app.staticTexts["Starts later"].exists)
        selectDay(offset: 1)
        XCTAssertTrue(app.staticTexts["Starts later"].exists)
        XCTAssertFalse(app.buttons["habit.progress.Starts later"].isEnabled)
        openDetail("Starts later")
        detailAction("Edit")
        reveal(app.buttons["habit.form.startDate"])
        XCTAssertEqual(app.buttons["habit.form.startDate"].value as? String, dateID(target))
        saveForm()
        app.terminate()
        app.launch()
        XCTAssertTrue(app.buttons["habit.add"].waitForExistence(timeout: 10))
        XCTAssertFalse(app.staticTexts["Starts later"].exists)
        selectDay(offset: 1)
        XCTAssertTrue(app.staticTexts["Starts later"].exists)
    }
}
