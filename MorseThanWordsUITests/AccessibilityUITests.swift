import XCTest

/// Runs Xcode's accessibility audit (contrast, element descriptions, hit regions, Dynamic Type,
/// clipped text, traits) on every screen, in light and dark mode and at the largest text size.
@MainActor
final class AccessibilityUITests: XCTestCase {
    private var app: XCUIApplication!

    override func tearDown() async throws {
        await MainActor.run { XCUIDevice.shared.appearance = .light }
        try await super.tearDown()
    }

    private func launch(appearance: XCUIDevice.Appearance = .light, largestText: Bool = false) {
        continueAfterFailure = true
        XCUIDevice.shared.appearance = appearance
        app = XCUIApplication()
        app.launchArguments = ["-uiTesting"]
        if largestText {
            app.launchArguments += ["-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityXXXL"]
        }
        app.launch()
    }

    private func tab(_ name: String) {
        app.buttons[name].firstMatch.tap()
        XCTAssertTrue(app.navigationBars[name].waitForExistence(timeout: 3))
    }

    private func audit(_ screen: String, _ types: XCUIAccessibilityAuditType = .all) {
        do {
            try app.performAccessibilityAudit(for: types) { [app] issue in
                // iOS 26 fades scroll content under the floating tab bar (scroll edge effect), so
                // text scrolled into that strip measures as low contrast. That is position, not
                // design: ignore contrast issues only inside the bottom bar zone.
                if issue.auditType == .contrast, let element = issue.element, let window = app?.windows.firstMatch,
                   element.frame.maxY > window.frame.maxY - 110 {
                    return true
                }
                // At launch the iPadOS floating tab bar builds its four labels without Dynamic
                // Type and fixes them on the first tab switch (measured: exactly four such
                // issues, gone after a tab round trip). The app itself has no UIKit labels, so a
                // Dynamic Type issue on an unexposed UILabel is system UI.
                if issue.auditType == .dynamicType, issue.element == nil, issue.detailedDescription.contains("UILabel") {
                    return true
                }
                XCTFail("[\(screen)] \(issue.auditType): \(issue.compactDescription) | \(issue.detailedDescription) — \(issue.element?.debugDescription.prefix(200) ?? "no element")")
                return true
            }
        } catch {
            XCTFail("[\(screen)] audit could not run: \(error)")
        }
    }

    private func auditAllScreens(_ types: XCUIAccessibilityAuditType = .all, label: String) {
        // Learn is the start tab; it is not tapped first, as re-tapping the selected tab in
        // the iPadOS floating tab bar leaves a transient system UILabel on screen.
        XCTAssertTrue(app.navigationBars["Learn"].waitForExistence(timeout: 5))
        audit("\(label) Learn empty", types)
        app.buttons["symbol-L"].tap()
        audit("\(label) Learn selected", types)

        tab("Practice")
        audit("\(label) Practice setup", types)
        app.buttons["historyButton"].tap()
        audit("\(label) History", types)
        app.navigationBars.buttons.firstMatch.tap()

        // Warning state: no usable characters.
        let characters = app.textFields["practiceCharacters"]
        characters.coordinate(withNormalizedOffset: CGVector(dx: 0.98, dy: 0.5)).tap()
        characters.typeText(String(repeating: XCUIKeyboardKey.delete.rawValue, count: 20) + "#")
        app.navigationBars["Practice"].staticTexts["Practice"].firstMatch.tap()  // dismiss keyboard
        audit("\(label) Practice warning", types)

        tab("Text")
        audit("\(label) Text editor", types)
        let editor = app.textViews["textInput"]
        editor.tap()
        editor.typeText("Hi #73")
        app.navigationBars["Text"].staticTexts["Text"].firstMatch.tap()  // dismiss keyboard
        XCTAssertTrue(app.staticTexts["textSkipped"].waitForExistence(timeout: 3))
        audit("\(label) Text with warning", types)

        tab("Settings")
        audit("\(label) Settings", types)
    }

    func testLightMode() throws {
        launch()
        auditAllScreens(label: "light")
    }

    func testDarkMode() throws {
        launch(appearance: .dark)
        auditAllScreens(label: "dark")
    }

    func testLargestTextSize() throws {
        launch(largestText: true)
        auditAllScreens([.dynamicType, .textClipped, .hitRegion, .elementDetection], label: "XXXL")
    }
}
