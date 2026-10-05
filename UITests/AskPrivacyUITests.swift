import XCTest

final class AskPrivacyUITests: XCTestCase {
    /// Run only on a disposable test simulator: --reset is intentionally used.
    @MainActor func testAskQueryChangesAndSourceDeletionRemoveCachedExactQuote() throws {
        continueAfterFailure = false
        let app = XCUIApplication(); app.launchArguments = ["--uitesting", "--reset", "--demo"]; app.launch()
        XCTAssertTrue(app.tabBars.buttons["Today"].waitForExistence(timeout: 20))
        if app.alerts.buttons["OK"].exists { app.alerts.buttons["OK"].tap() }
        app.tabBars.buttons["Today"].tap()
        tap(app.buttons["Ask saved info"], in: app)
        let query = app.textFields["ask-query"]
        XCTAssertTrue(query.waitForExistence(timeout: 5)); query.tap(); query.typeText("metoprolol")
        tap(app.buttons["ask-find"], in: app)
        let exactQuote = app.staticTexts["“I report taking metoprolol succinate 50 mg oral daily.”"]
        XCTAssertTrue(exactQuote.waitForExistence(timeout: 5), "The fictional reviewed quote must be present before invalidation is tested")

        let suffix = " fictional-nomatch"
        query.tap(); query.typeText(suffix)
        XCTAssertTrue(exactQuote.waitForNonExistence(timeout: 5), "Changing the question invalidates earlier results immediately")
        XCTAssertFalse(app.buttons["Save this as a question for my care team"].exists)
        query.typeText(String(repeating: XCUIKeyboardKey.delete.rawValue, count: suffix.count))
        tap(app.buttons["ask-find"], in: app)
        XCTAssertTrue(exactQuote.waitForExistence(timeout: 5))
        tap(app.buttons["Synthetic · My medication update"].firstMatch, in: app)
        XCTAssertTrue(app.navigationBars["Source evidence"].waitForExistence(timeout: 5))
        tap(app.buttons["Delete source and its claims"], in: app)
        XCTAssertTrue(app.navigationBars["Deletion preview"].waitForExistence(timeout: 5))
        scrollContent(app, up: true)
        tap(app.buttons["impact-delete"], in: app)
        XCTAssertTrue(app.buttons["Delete source"].waitForExistence(timeout: 5)); app.buttons["Delete source"].tap()
        XCTAssertTrue(app.navigationBars["Source evidence"].waitForNonExistence(timeout: 5))
        XCTAssertTrue(app.navigationBars["Ask"].waitForExistence(timeout: 5))
        XCTAssertTrue(exactQuote.waitForNonExistence(timeout: 5), "Deleting source evidence must remove its cached summary/quote on return")
        XCTAssertFalse(app.buttons["Save this as a question for my care team"].exists)
        tap(app.buttons["ask-find"], in: app)
        XCTAssertFalse(exactQuote.exists, "A fresh local search must not return the deleted evidence")
        XCTAssertTrue(app.staticTexts.matching(NSPredicate(format: "identifier BEGINSWITH 'ask-quote-'")).firstMatch.waitForExistence(timeout: 5), "Other reviewed fictional sources remain searchable")
    }
    @MainActor private func tap(_ element: XCUIElement, in app: XCUIApplication) {
        for _ in 0..<16 where !element.isHittable { scrollContent(app, up: true) }
        XCTAssertTrue(element.waitForExistence(timeout: 5)); XCTAssertTrue(element.isHittable); element.tap()
    }
    @MainActor private func scrollContent(_ app: XCUIApplication, up: Bool) {
        let screen = app.frame
        let top = max(screen.minY + 155, app.navigationBars.firstMatch.frame.maxY + 70)
        let keyboardTop = app.keyboards.firstMatch.exists ? app.keyboards.firstMatch.frame.minY : screen.maxY
        let bottom = min(screen.maxY - 175, keyboardTop - 45)
        guard bottom > top + 35 else { return }
        let start = app.coordinate(withNormalizedOffset: .zero).withOffset(CGVector(dx: screen.midX, dy: up ? bottom : top))
        let end = app.coordinate(withNormalizedOffset: .zero).withOffset(CGVector(dx: screen.midX, dy: up ? top : bottom))
        start.press(forDuration: 0.08, thenDragTo: end)
    }
}
