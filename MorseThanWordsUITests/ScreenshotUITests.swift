import XCTest

/// App Store screenshots. Skipped in normal test runs; `scripts/make-screenshots.sh` runs it with
/// TEST_RUNNER_SCREENSHOTS=1 and exports the attachments.
@MainActor
final class ScreenshotUITests: XCTestCase {
    private var app: XCUIApplication!

    private func snap(_ name: String) {
        Thread.sleep(forTimeInterval: 1)  // let animations settle
        let attachment = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    private func tab(_ name: String) {
        app.buttons[name].firstMatch.tap()
        XCTAssertTrue(app.navigationBars[name].waitForExistence(timeout: 3))
    }

    func testAppStoreScreenshots() throws {
        try XCTSkipUnless(ProcessInfo.processInfo.environment["SCREENSHOTS"] == "1", "Run via scripts/make-screenshots.sh")
        continueAfterFailure = false
        XCUIDevice.shared.appearance = .light
        app = XCUIApplication()
        app.launchArguments = ["-uiTesting"]
        app.launch()

        // 1. Learn: a character selected.
        XCTAssertTrue(app.navigationBars["Learn"].waitForExistence(timeout: 5))
        app.buttons["symbol-K"].tap()
        snap("01-learn")

        // 2. Practice setup.
        tab("Practice")
        snap("02-practice-setup")

        // 3. Practice result, revealed.
        app.buttons["practiceCount-Decrement"].tap()
        app.buttons["practiceCount-Decrement"].tap()
        app.buttons["practiceCount-Decrement"].tap()  // 35 characters
        app.buttons["startPractice"].tap()
        XCTAssertTrue(app.buttons["revealButton"].waitForExistence(timeout: 60))
        app.buttons["revealButton"].tap()
        snap("03-practice-reveal")
        app.buttons["newSessionButton"].tap()

        // 4. Text playing with the ticker.
        tab("Text")
        let editor = app.textViews["textInput"]
        editor.tap()
        editor.typeText(String(repeating: "CQ CQ CQ DE HA5MTW HA5MTW PSE K ", count: 6))
        app.buttons["keyboardDone"].firstMatch.tap()
        XCTAssertTrue(app.staticTexts["textSummary"].waitForExistence(timeout: 3))
        app.buttons["playText"].tap()
        Thread.sleep(forTimeInterval: 2.5)
        snap("04-text-playing")
        app.buttons["textStopButton"].tap()

        // 5. Settings with radio conditions.
        tab("Settings")
        app.switches["farnsworthToggle"].switches.firstMatch.tap()
        snap("05-settings")
        // A measured scroll so the radio conditions start just below the navigation bar.
        let form = app.collectionViews.firstMatch
        form.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.8))
            .press(forDuration: 0.05, thenDragTo: form.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.25)))
        for id in ["noiseToggle", "fadingToggle", "filterToggle"] {
            let toggle = app.switches[id]
            if toggle.exists, toggle.isHittable { toggle.switches.firstMatch.tap() }
        }
        snap("06-radio-conditions")
    }
}
