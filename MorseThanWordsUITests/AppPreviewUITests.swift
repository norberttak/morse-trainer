import XCTest

/// Scripted walkthrough for the App Store app preview video (about 25 s at real speed).
/// Skipped in normal runs; `scripts/make-app-preview.sh` records the simulator screen while this
/// runs and cuts the video at the PREVIEW_MARK lines printed below.
@MainActor
final class AppPreviewUITests: XCTestCase {
    private func pause(_ seconds: Double) {
        Thread.sleep(forTimeInterval: seconds)
    }

    func testAppPreviewWalkthrough() throws {
        try XCTSkipUnless(ProcessInfo.processInfo.environment["APP_PREVIEW"] == "1", "Run via scripts/make-app-preview.sh")
        continueAfterFailure = false
        XCUIDevice.shared.appearance = .light

        let app = XCUIApplication()
        // "-practiceCount 10" sets the session length through the launch-argument defaults domain,
        // which saves eight stepper taps on camera.
        app.launchArguments = ["-uiTesting", "-realSpeed", "-practiceCount", "10"]
        // Pre-filled text for the Text tab, so no typing is needed on camera.
        app.launchEnvironment["UITEST_IMPORT_BASE64"] = Data("CQ CQ CQ DE HA5MTW HA5MTW PSE K".utf8).base64EncodedString()
        app.launch()
        XCTAssertTrue(app.navigationBars["Learn"].waitForExistence(timeout: 10))
        pause(0.5)
        print("PREVIEW_MARK start")

        // Learn: hear and see a few characters.
        for symbol in ["K", "M"] {
            app.buttons["symbol-\(symbol)"].tap()
            pause(1.2)
        }

        // Practice: a short 10-character session, then reveal.
        app.buttons["Practice"].firstMatch.tap()
        XCTAssertTrue(app.buttons["startPractice"].waitForExistence(timeout: 3))
        pause(0.8)
        app.buttons["startPractice"].tap()
        XCTAssertTrue(app.buttons["revealButton"].waitForExistence(timeout: 30))
        pause(0.6)
        app.buttons["revealButton"].tap()
        pause(2)

        // Text: play the pre-filled text with the ticker.
        app.buttons["Text"].firstMatch.tap()
        XCTAssertTrue(app.buttons["playText"].waitForExistence(timeout: 3))
        pause(0.6)
        app.buttons["playText"].tap()
        pause(3.5)
        app.buttons["textStopButton"].tap()
        pause(0.5)

        // Settings: radio conditions.
        app.buttons["Settings"].firstMatch.tap()
        XCTAssertTrue(app.navigationBars["Settings"].waitForExistence(timeout: 3))
        pause(1)
        app.swipeUp()
        app.switches["noiseToggle"].switches.firstMatch.tap()
        pause(1.5)
        print("PREVIEW_MARK end")
    }
}
