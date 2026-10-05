import XCTest

@MainActor
final class SettingsUITests: XCTestCase {
    private var app: XCUIApplication!

    private func launch(keepSettings: Bool = false) {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments = ["-uiTesting"] + (keepSettings ? ["-keepSettings"] : [])
        app.launch()
        app.buttons["Settings"].firstMatch.tap()
        XCTAssertTrue(app.navigationBars["Settings"].waitForExistence(timeout: 5))
    }

    /// Number at the start of a value label such as "27 WPM".
    private func number(_ identifier: String) -> Int {
        let label = app.staticTexts["\(identifier)Value"].label
        return Int(label.prefix { $0.isNumber }) ?? -1
    }

    private func scrollTo(_ element: XCUIElement) {
        var swipes = 0
        while !(element.exists && element.isHittable) && swipes < 10 {
            app.swipeUp()
            swipes += 1
        }
        XCTAssertTrue(element.isHittable, "\(element) not reachable")
    }

    func testDefaults() throws {
        launch()
        XCTAssertEqual(app.staticTexts["characterSpeedValue"].label, "20 WPM")
        XCTAssertEqual(app.staticTexts["pitchValue"].label, "600 Hz")
        XCTAssertFalse(app.sliders["overallSpeed"].exists)
    }

    func testSettingsSurviveRelaunch() throws {
        launch()
        app.sliders["characterSpeed"].adjust(toNormalizedSliderPosition: 0.8)
        app.sliders["pitch"].adjust(toNormalizedSliderPosition: 0.1)
        let speed = app.staticTexts["characterSpeedValue"].label
        let pitch = app.staticTexts["pitchValue"].label
        XCTAssertNotEqual(speed, "20 WPM")
        XCTAssertNotEqual(pitch, "600 Hz")

        let noise = app.switches["noiseToggle"]
        scrollTo(noise)
        noise.switches.firstMatch.tap()
        XCTAssertTrue(app.sliders["snr"].waitForExistence(timeout: 2))

        app.terminate()
        launch(keepSettings: true)

        XCTAssertEqual(app.staticTexts["characterSpeedValue"].label, speed)
        XCTAssertEqual(app.staticTexts["pitchValue"].label, pitch)
        scrollTo(app.switches["noiseToggle"])
        XCTAssertEqual(app.switches["noiseToggle"].value as? String, "1")
        XCTAssertTrue(app.sliders["snr"].exists)
    }

    func testOverallSpeedNeverExceedsCharacterSpeed() throws {
        launch()
        app.switches["farnsworthToggle"].switches.firstMatch.tap()
        let overall = app.sliders["overallSpeed"]
        XCTAssertTrue(overall.waitForExistence(timeout: 2))

        overall.adjust(toNormalizedSliderPosition: 1)
        XCTAssertEqual(number("overallSpeed"), number("characterSpeed"))

        app.sliders["characterSpeed"].adjust(toNormalizedSliderPosition: 0.2)
        XCTAssertLessThanOrEqual(number("overallSpeed"), number("characterSpeed"))
        XCTAssertGreaterThanOrEqual(number("overallSpeed"), 5)
    }

    func testPreviewStartsAndStops() throws {
        launch()
        let preview = app.buttons["previewButton"]
        XCTAssertEqual(preview.label, "Preview")
        preview.tap()
        XCTAssertTrue(app.buttons["Stop"].waitForExistence(timeout: 2))
        app.buttons["previewButton"].tap()
        XCTAssertTrue(app.buttons["Preview"].waitForExistence(timeout: 2))
    }

    func testResetToDefaults() throws {
        launch()
        app.sliders["characterSpeed"].adjust(toNormalizedSliderPosition: 0.9)
        XCTAssertNotEqual(app.staticTexts["characterSpeedValue"].label, "20 WPM")

        let reset = app.buttons["resetButton"]
        scrollTo(reset)
        reset.tap()
        app.buttons["confirmResetButton"].firstMatch.tap()

        app.swipeDown()
        app.swipeDown()
        XCTAssertTrue(app.staticTexts["characterSpeedValue"].waitForExistence(timeout: 2))
        XCTAssertEqual(app.staticTexts["characterSpeedValue"].label, "20 WPM")
    }
}
