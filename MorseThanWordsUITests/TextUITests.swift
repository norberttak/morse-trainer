import XCTest

@MainActor
final class TextUITests: XCTestCase {
    private var app: XCUIApplication!

    private func launch(importing data: Data? = nil, repeated repeats: Int = 1) {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments = ["-uiTesting"]
        if let data {
            app.launchEnvironment["UITEST_IMPORT_BASE64"] = data.base64EncodedString()
            app.launchEnvironment["UITEST_IMPORT_REPEAT"] = String(repeats)
        }
        app.launch()
        app.buttons["Text"].firstMatch.tap()
        XCTAssertTrue(app.textViews["textInput"].waitForExistence(timeout: 5))
    }

    private func type(_ text: String) {
        let editor = app.textViews["textInput"]
        editor.tap()
        editor.typeText(text)
    }

    func testPlayTypedTextToTheEnd() throws {
        launch()
        XCTAssertFalse(app.buttons["playText"].isEnabled)
        type("CQ CQ DE TEST")
        let summary = app.staticTexts["textSummary"]
        XCTAssertTrue(summary.waitForExistence(timeout: 3))
        XCTAssertTrue(summary.label.hasPrefix("10 characters"), summary.label)

        app.buttons["playText"].tap()
        XCTAssertTrue(app.descendants(matching: .any)["textTicker"].waitForExistence(timeout: 3))
        XCTAssertTrue(app.staticTexts["textProgress"].label.hasSuffix("/ 10"), app.staticTexts["textProgress"].label)

        // 50 WPM in UI-test mode: 10 characters finish within a few seconds and the editor returns.
        XCTAssertTrue(app.textViews["textInput"].waitForExistence(timeout: 20))
        XCTAssertEqual(app.textViews["textInput"].value as? String, "CQ CQ DE TEST")
    }

    func testPauseResumeStopAndHideText() throws {
        launch()
        type(String(repeating: "PARIS ", count: 40))
        XCTAssertTrue(app.staticTexts["textSummary"].waitForExistence(timeout: 3))
        app.buttons["playText"].tap()

        let pause = app.buttons["textPauseButton"]
        XCTAssertTrue(pause.waitForExistence(timeout: 3))
        pause.tap()
        XCTAssertEqual(pause.label, "Resume")
        pause.tap()
        XCTAssertEqual(pause.label, "Pause")

        app.switches["showTextToggle"].switches.firstMatch.tap()
        XCTAssertFalse(app.descendants(matching: .any)["textTicker"].exists)
        XCTAssertTrue(app.staticTexts["Text hidden — copy by ear"].exists)

        app.buttons["textStopButton"].tap()
        XCTAssertTrue(app.textViews["textInput"].waitForExistence(timeout: 3))
    }

    func testReportsSkippedCharacters() throws {
        launch()
        type("Hi #1 €")
        let skipped = app.staticTexts["textSkipped"]
        XCTAssertTrue(skipped.waitForExistence(timeout: 3))
        XCTAssertEqual(skipped.label, "2 unsupported characters will be skipped: # €")
    }

    func testImportLatin1File() throws {
        // "Café 73" in ISO-8859-1 (é = 0xE9 is invalid UTF-8).
        launch(importing: Data([0x43, 0x61, 0x66, 0xE9, 0x20, 0x37, 0x33]))
        XCTAssertEqual(app.textViews["textInput"].value as? String, "Café 73")
        XCTAssertTrue(app.staticTexts["textSummary"].waitForExistence(timeout: 3))
        XCTAssertTrue(app.staticTexts["textSummary"].label.hasPrefix("6 characters"))
    }

    func testImportLargeFileWarnsAboutLength() throws {
        // ~1 MB file, sent as one line repeated.
        let line = "The quick brown fox jumps over the lazy dog 0123456789.\n"
        launch(importing: Data(line.utf8), repeated: 1_048_576 / line.utf8.count + 1)
        XCTAssertTrue(app.staticTexts["textTruncated"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.buttons["playText"].isEnabled)

        app.buttons["clearButton"].firstMatch.tap()
        XCTAssertFalse(app.staticTexts["textTruncated"].waitForExistence(timeout: 2))
    }
}
