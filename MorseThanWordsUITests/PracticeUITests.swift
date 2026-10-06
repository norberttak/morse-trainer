import XCTest

@MainActor
final class PracticeUITests: XCTestCase {
    private var app: XCUIApplication!

    private func launch() {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments = ["-uiTesting"]
        app.launch()
        app.buttons["Practice"].firstMatch.tap()
        XCTAssertTrue(app.buttons["startPractice"].waitForExistence(timeout: 5))
    }

    private func setCharacters(_ text: String) {
        let field = app.textFields["practiceCharacters"]
        // Tap near the right edge so the cursor lands after the existing text.
        field.coordinate(withNormalizedOffset: CGVector(dx: 0.98, dy: 0.5)).tap()
        let existing = (field.value as? String) ?? ""
        field.typeText(String(repeating: XCUIKeyboardKey.delete.rawValue, count: existing.count + 5))
        field.typeText(text)
        app.buttons["keyboardDone"].firstMatch.tap()
    }

    private func setCount(_ count: Int) {
        // Default is 50, step 5.
        for _ in 0..<((50 - count) / 5) {
            app.buttons["practiceCount-Decrement"].tap()
        }
    }

    /// Runs a 10-character session of K/M/R in groups of 5 and returns after the result shows.
    private func runShortSession() {
        setCharacters("KMR")
        setCount(10)
        XCTAssertTrue(app.staticTexts["3 different characters. Prosigns can be entered as <AR>, <SK>, <BT>, <KN> or <SOS>."].exists)
        app.buttons["startPractice"].tap()
        // UI-test mode plays at 50 WPM with no countdown: 10 characters take a few seconds.
        XCTAssertTrue(app.staticTexts["practiceProgress"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["revealButton"].waitForExistence(timeout: 30))
    }

    func testCompleteSessionRevealsGroupsAndSavesHistory() throws {
        launch()
        runShortSession()

        XCTAssertFalse(app.staticTexts["revealGroup-0"].exists, "Characters must stay hidden until revealed")
        app.buttons["revealButton"].tap()

        let groups = (0..<2).map { app.staticTexts["revealGroup-\($0)"] }
        for group in groups {
            XCTAssertTrue(group.waitForExistence(timeout: 2))
            // Label: "Group 1: K M R K M"
            let characters = group.label.split(separator: ":").last!.split(separator: " ")
            XCTAssertEqual(characters.count, 5)
            XCTAssertTrue(characters.allSatisfy { ["K", "M", "R"].contains($0) }, group.label)
        }
        XCTAssertFalse(app.staticTexts["revealGroup-2"].exists)

        app.buttons["newSessionButton"].tap()
        app.buttons["historyButton"].tap()
        let row = app.descendants(matching: .any)["historyRow"].firstMatch
        XCTAssertTrue(row.waitForExistence(timeout: 2))
        XCTAssertTrue(row.label.contains("10 characters"), row.label)

        row.tap()
        XCTAssertTrue(app.staticTexts["revealGroup-1"].waitForExistence(timeout: 2))
        app.navigationBars.buttons.firstMatch.tap()

        // Delete with swipe.
        row.swipeLeft()
        app.buttons["Delete"].tap()
        XCTAssertTrue(app.staticTexts["No Sessions Yet"].waitForExistence(timeout: 2))
    }

    func testStoppingEarlySavesNothing() throws {
        launch()
        setCharacters("KMR")
        // 500 characters: long enough to stop mid-way.
        app.buttons["practiceCount-Increment"].press(forDuration: 4)
        app.buttons["startPractice"].tap()
        XCTAssertTrue(app.buttons["stopButton"].waitForExistence(timeout: 5))

        app.buttons["pauseButton"].tap()
        XCTAssertEqual(app.buttons["pauseButton"].label, "Resume")
        app.buttons["pauseButton"].tap()
        XCTAssertEqual(app.buttons["pauseButton"].label, "Pause")

        app.buttons["stopButton"].tap()
        XCTAssertTrue(app.buttons["startPractice"].waitForExistence(timeout: 2))
        app.buttons["historyButton"].tap()
        XCTAssertTrue(app.staticTexts["No Sessions Yet"].waitForExistence(timeout: 2))
    }

    func testEmptyCharacterSetDisablesStart() throws {
        launch()
        setCharacters("#!")
        // "!" is supported, so only "#" is ignored: still startable.
        XCTAssertTrue(app.buttons["startPractice"].isEnabled)
        setCharacters("#")
        XCTAssertFalse(app.buttons["startPractice"].isEnabled)
        XCTAssertTrue(app.staticTexts["Enter at least one letter, number or punctuation mark."].exists)
    }
}
