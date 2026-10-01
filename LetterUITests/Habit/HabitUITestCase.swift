import XCTest

@MainActor
class HabitUITestCase: XCTestCase {
    var app: XCUIApplication!
    var session: String!

    override func setUpWithError() throws {
        continueAfterFailure = false
        session = UUID().uuidString
        app = XCUIApplication()
        app.launchEnvironment["LETTER_UI_TEST_SESSION"] = session
        // Argument-domain preferences do not change the user's saved language.
        app.launchArguments = ["-app.language", "en", "-AppleLanguages", "(en)",
                               "-AppleLocale", "en_US"]
        addUIInterruptionMonitor(withDescription: "Notification permission") { alert in
            let button = alert.buttons["Allow"]
            guard button.exists else { return false }
            button.tap()
            return true
        }
        app.launch()
        XCTAssertTrue(app.buttons["habit.add"].waitForExistence(timeout: 15))
    }

    override func tearDownWithError() throws {
        if let app, let testRun, testRun.failureCount > 0 {
            let screenshot = XCTAttachment(screenshot: app.screenshot())
            screenshot.lifetime = .keepAlways
            add(screenshot)
            let tree = XCTAttachment(string: app.debugDescription)
            tree.lifetime = .keepAlways
            add(tree)
        }
        app?.terminate()
        app = nil
    }

    func openForm() {
        app.buttons["habit.add"].tap()
        XCTAssertTrue(app.textFields["habit.form.name"].waitForExistence(timeout: 5))
    }

    func reveal(_ element: XCUIElement, file: StaticString = #filePath, line: UInt = #line) {
        dismissKeyboard()
        let scroll = app.scrollViews["habit.form.scroll"]
        XCTAssertTrue(scroll.waitForExistence(timeout: 5), file: file, line: line)
        // Stay between the navigation and tab bars on every screen size.
        let top = max(scroll.frame.minY, app.navigationBars.firstMatch.frame.maxY) + 20
        let tabBar = app.tabBars.firstMatch
        let bottom = min(scroll.frame.maxY, tabBar.exists ? tabBar.frame.minY : app.frame.maxY) - 20
        for _ in 0..<12 {
            if element.exists && element.isHittable { return }
            let moveDown = element.exists && element.frame.midY < top
            let startY = moveDown ? top : bottom
            let endY = moveDown ? bottom : top
            let origin = app.coordinate(withNormalizedOffset: .zero)
            let x = scroll.frame.midX
            origin.withOffset(CGVector(dx: x, dy: startY))
                .press(forDuration: 0.05, thenDragTo: origin.withOffset(CGVector(dx: x, dy: endY)))
        }
        XCTFail("Control is not reachable: \(element)", file: file, line: line)
    }

    func replace(_ identifier: String, with text: String) {
        let field = app.textFields[identifier]
        reveal(field)
        field.tap()
        let value = field.value as? String ?? ""
        let placeholder = field.placeholderValue ?? ""
        if value != placeholder && !value.isEmpty {
            // A fresh focus puts the insertion point at the end of these fields.
            field.typeText(String(repeating: XCUIKeyboardKey.delete.rawValue, count: value.count))
        }
        field.typeText(text)
        dismissKeyboard()
    }

    func dismissKeyboard() {
        // The keyboard may still be animating into the accessibility tree.
        let controls = app.buttons.matching(identifier: "keyboard.dismiss")
        if controls.firstMatch.waitForExistence(timeout: 2) {
            // A sheet may leave its presenting screen in the accessibility tree.
            guard let done = controls.allElementsBoundByIndex.first(where: { $0.isHittable }) else {
                XCTFail("No visible keyboard dismissal control")
                return
            }
            done.tap()
            let hidden = XCTNSPredicateExpectation(
                predicate: NSPredicate(format: "exists == false"), object: controls.firstMatch
            )
            XCTAssertEqual(XCTWaiter.wait(for: [hidden], timeout: 5), .completed)
        }
    }

    func createHabit(_ name: String = "Read daily", todo: Bool = false, target: Int = 5) {
        openForm()
        replace("habit.form.name", with: name)
        if todo {
            reveal(app.buttons["Todo"])
            app.buttons["Todo"].tap()
        } else {
            replace("habit.form.target", with: String(target))
            replace("habit.form.unit", with: "pages")
        }
        saveForm()
        XCTAssertTrue(app.staticTexts[name].waitForExistence(timeout: 5))
    }

    func saveForm() {
        app.buttons["habit.form.save"].tap()
        // Trigger interruption handling if a reminder asks for permission.
        if XCUIApplication(bundleIdentifier: "com.apple.springboard").alerts.firstMatch.exists {
            app.tap()
        }
        XCTAssertTrue(app.buttons["habit.add"].waitForExistence(timeout: 5)
                      || app.buttons["habit.detail.menu"].waitForExistence(timeout: 5))
    }

    func openDetail(_ name: String = "Read daily") {
        app.staticTexts[name].tap()
        XCTAssertTrue(app.buttons["habit.detail.menu"].waitForExistence(timeout: 5))
    }

    func detailAction(_ title: String) {
        app.buttons["habit.detail.menu"].tap()
        app.buttons[title].tap()
    }

    func cancelConfirmation(_ title: String) {
        XCTAssertTrue(app.staticTexts.matching(NSPredicate(format:
            "label CONTAINS %@", title)).firstMatch.waitForExistence(timeout: 5))
        if app.buttons["Cancel"].exists {
            app.buttons["Cancel"].tap()
        } else {
            // Newer iOS confirmation popovers dismiss when tapped outside.
            app.coordinate(withNormalizedOffset: CGVector(dx: 0.1, dy: 0.65)).tap()
        }
    }

    func back() {
        app.navigationBars.buttons.element(boundBy: 0).tap()
    }

    func status(_ name: String = "Read daily") -> XCUIElement {
        app.staticTexts["habit.status.\(name)"]
    }

    func assertStatus(_ text: String, name: String = "Read daily",
                      file: StaticString = #filePath, line: UInt = #line) {
        let predicate = NSPredicate(format: "label == %@", text)
        let expectation = XCTNSPredicateExpectation(predicate: predicate, object: status(name))
        XCTAssertEqual(XCTWaiter.wait(for: [expectation], timeout: 5), .completed,
                       file: file, line: line)
    }

    func progress(_ name: String = "Read daily") {
        app.buttons["habit.progress.\(name)"].tap()
    }

    func submitCount(_ value: String) {
        XCTAssertTrue(app.buttons["habit.entry.completeGoal"].waitForExistence(timeout: 5))
        for character in value { app.buttons[String(character)].tap() }
        app.buttons["Done"].tap()
    }

    func swipeEntry(_ direction: String, name: String = "Read daily") {
        let row = app.cells.containing(.staticText, identifier: name).firstMatch
        XCTAssertTrue(row.exists)
        if direction == "skip" { row.swipeRight() } else { row.swipeLeft() }
        app.buttons["habit.entry.\(direction)"].tap()
    }

    func swipeWeek(forward: Bool) {
        let day = app.buttons.matching(NSPredicate(format:
            "identifier BEGINSWITH 'habit.day.' AND value == 'selected'")).firstMatch
        let y = day.frame.midY / app.frame.height
        let start = app.coordinate(withNormalizedOffset: CGVector(dx: forward ? 0.85 : 0.15, dy: y))
        let end = app.coordinate(withNormalizedOffset: CGVector(dx: forward ? 0.15 : 0.85, dy: y))
        start.press(forDuration: 0.05, thenDragTo: end)
    }

    func returnToToday() {
        app.navigationBars.buttons.matching(NSPredicate(format:
            "identifier != 'habit.add' AND identifier != 'habit.statistics'")).firstMatch.tap()
    }

    func selectStatisticsMode(_ title: String) {
        app.buttons["habit.statistics.mode"].tap()
        let choice = app.buttons[title]
        XCTAssertTrue(choice.waitForExistence(timeout: 5))
        choice.tap()
    }

    func statistics(byHabit: Bool = false) {
        app.buttons["habit.statistics"].tap()
        XCTAssertTrue(app.buttons["habit.statistics.mode"].waitForExistence(timeout: 5))
        if byHabit { selectStatisticsMode("By Habit") }

    }
}
