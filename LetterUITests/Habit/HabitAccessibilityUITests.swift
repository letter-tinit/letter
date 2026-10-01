import XCTest

@MainActor
final class HabitAccessibilityUITests: HabitUITestCase {
    func testLargeTextKeepsFormAndTrackingControlsReachable() {
        app.terminate()
        app.launchArguments += ["-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityXXXL"]
        app.launch()
        XCTAssertTrue(app.buttons["habit.add"].waitForExistence(timeout: 10))
        openForm()
        replace("habit.form.name", with: "Large text")
        reveal(app.buttons["Todo"])
        app.buttons["Todo"].tap()
        reveal(app.buttons["habit.form.endDate"])
        XCTAssertTrue(app.buttons["habit.form.endDate"].isHittable)
        reveal(app.buttons["habit.reminder.add"])
        XCTAssertTrue(app.buttons["habit.reminder.add"].isHittable)
        saveForm()
        progress("Large text")
        assertStatus("1/1", name: "Large text")
        openDetail("Large text")
        XCTAssertTrue(app.buttons["habit.detail.menu"].isHittable)
    }

    func testVietnameseCreationAndDetailsUseStableControls() {
        app.terminate()
        app.launchArguments = ["-app.language", "vi", "-AppleLanguages", "(vi)", "-AppleLocale", "vi_VN"]
        app.launch()
        XCTAssertTrue(app.buttons["habit.add"].waitForExistence(timeout: 10))
        openForm()
        replace("habit.form.name", with: "Đọc sách")
        saveForm()
        XCTAssertTrue(app.staticTexts["Đọc sách"].waitForExistence(timeout: 5))
        openDetail("Đọc sách")
        XCTAssertTrue(app.staticTexts["habit.detail.goal"].exists)
        XCTAssertFalse(app.staticTexts["habit.detail.goal"].label.contains("times"))
    }
}
