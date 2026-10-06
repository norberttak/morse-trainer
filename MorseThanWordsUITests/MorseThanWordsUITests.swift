import XCTest

@MainActor
final class LearnUITests: XCTestCase {
    private var app: XCUIApplication!

    private func launch() {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments = ["-uiTesting"]
        app.launch()
    }

    func testTappingLShowsItsCode() throws {
        launch()
        XCTAssertTrue(app.staticTexts["Tap a character to hear it"].waitForExistence(timeout: 5))

        app.buttons["symbol-L"].tap()

        XCTAssertEqual(app.staticTexts["selectedSymbol"].label, "L")
        // The drawn pattern carries the spoken form for VoiceOver.
        XCTAssertEqual(app.descendants(matching: .any)["selectedPattern"].label, "dit dah dit dit")
        XCTAssertTrue(app.buttons["symbol-L"].isSelected)
    }

    func testSelectingAnotherCharacterReplacesTheCode() throws {
        launch()
        app.buttons["symbol-L"].tap()
        app.buttons["symbol-F"].tap()
        XCTAssertEqual(app.staticTexts["selectedSymbol"].label, "F")
        XCTAssertEqual(app.descendants(matching: .any)["selectedPattern"].label, "dit dit dah dit")
        XCTAssertTrue(app.buttons["replayButton"].isHittable)
        app.buttons["replayButton"].tap()
    }

    func testAllSectionsAreReachable() throws {
        launch()
        for identifier in ["symbol-A", "symbol-0", "symbol-?", "symbol-SOS"] {
            let button = app.buttons[identifier]
            var swipes = 0
            while !(button.exists && button.isHittable) && swipes < 8 {
                app.scrollViews.firstMatch.swipeUp()
                swipes += 1
            }
            XCTAssertTrue(button.isHittable, "\(identifier) not reachable")
        }
        app.buttons["symbol-SOS"].tap()
        XCTAssertEqual(app.staticTexts["selectedSymbol"].label, "prosign S O S")
    }

    func testTabsExist() throws {
        launch()
        // iPhone: bottom tab bar. iPad (iPadOS 18+): floating tab bar at the top, not a `tabBars` element.
        for tab in ["Learn", "Practice", "Text", "Settings"] {
            XCTAssertTrue(app.buttons[tab].firstMatch.exists, "\(tab) tab missing")
        }
        for tab in ["Practice", "Text", "Settings", "Learn"] {
            app.buttons[tab].firstMatch.tap()
            XCTAssertTrue(app.navigationBars[tab].waitForExistence(timeout: 2), "\(tab) screen did not open")
        }
    }
}
