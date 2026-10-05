import XCTest
import UIKit

final class CapturePipelineUITests: XCTestCase {
    @MainActor func testSystemPasteLongMultilineTextSavesAndSurvivesRelaunch() throws {
        continueAfterFailure = false
        let app = emptyApp()
        app.buttons["global-add"].tap()
        let title = app.textFields["capture-title"]
        XCTAssertTrue(title.waitForExistence(timeout: 5)); title.tap(); title.typeText("Fictional pasted care note")
        let text = app.textViews["capture-text"]
        XCTAssertTrue(text.waitForExistence(timeout: 5))
        let pasted = "Allergy: latex\n" + (1...80).map { "Fictional line \($0): bring records 🫶🏽." }.joined(separator: "\n")
        UIPasteboard.general.string = pasted
        let paste = app.buttons["capture-text-paste"]
        for _ in 0..<4 where !paste.isHittable { app.swipeUp() }
        XCTAssertTrue(paste.waitForExistence(timeout: 5)); XCTAssertTrue(paste.isEnabled); paste.tap()
        if app.alerts.buttons["Allow Paste"].exists { app.alerts.buttons["Allow Paste"].tap() }
        XCTAssertTrue(text.waitForExistence(timeout: 5))
        XCTAssertEqual(text.value as? String, pasted)
        text.tap()
        let done = app.buttons["capture-text-done"]
        XCTAssertTrue(done.waitForExistence(timeout: 5)); done.tap()
        XCTAssertEqual(app.keyboards.count, 0)
        // Scroll the outer form edge, away from the long editor's own scrolling text.
        for _ in 0..<12 where !app.buttons["save-evidence"].isHittable { scrollOuterForm(app) }
        app.buttons["save-evidence"].tap()
        XCTAssertTrue(app.buttons["Edit title, date, or working text"].waitForExistence(timeout: 10))
        app.terminate(); app.launchArguments = ["--uitesting"]; app.launch()
        XCTAssertTrue(app.tabBars.buttons["Sources"].waitForExistence(timeout: 15)); app.tabBars.buttons["Sources"].tap()
        app.staticTexts["Fictional pasted care note"].tap()
        app.buttons["Edit title, date, or working text"].tap()
        let edited = app.textViews["source-edit-text"]
        for _ in 0..<6 where !edited.exists { app.swipeUp() }
        XCTAssertTrue(edited.waitForExistence(timeout: 5)); XCTAssertEqual(edited.value as? String, pasted)
        attach(app, "Lossless long multiline paste after relaunch")
        app.buttons["Cancel"].tap()
    }

    @MainActor func testKeyboardDoneAndClearedWorkingTextKeepOriginalEvidence() throws {
        continueAfterFailure = false
        let app = emptyApp(); app.buttons["global-add"].tap()
        let title = app.textFields["capture-title"]; XCTAssertTrue(title.waitForExistence(timeout: 5)); title.tap(); title.typeText("Fictional editable source")
        let text = app.textViews["capture-text"]; text.tap(); text.typeText("Allergy: latex\nBring records")
        let done = app.buttons["capture-text-done"]
        XCTAssertTrue(done.waitForExistence(timeout: 5)); done.tap()
        XCTAssertEqual(app.keyboards.count, 0)
        for _ in 0..<6 where !app.buttons["save-evidence"].isHittable { app.swipeUp() }
        app.buttons["save-evidence"].tap()
        XCTAssertTrue(app.buttons["Edit title, date, or working text"].waitForExistence(timeout: 10)); app.buttons["Edit title, date, or working text"].tap()
        let edited = app.textViews["source-edit-text"]
        for _ in 0..<5 where !edited.isHittable { app.swipeUp() }
        edited.tap()
        let editingDone = app.buttons["source-edit-text-done"]
        XCTAssertTrue(editingDone.waitForExistence(timeout: 5)); editingDone.tap()
        XCTAssertEqual(app.keyboards.count, 0)
        let original = "Allergy: latex\nBring records"
        XCTAssertEqual(edited.value as? String, original)
        // Select the entire actual focused editor with the native editing menu.
        // A coordinate cannot establish an end insertion point, and simulator
        // hardware shortcuts do not reliably route to the software keyboard.
        edited.tap()
        XCTAssertTrue(editingDone.waitForExistence(timeout: 5))
        XCTAssertTrue(app.keyboards.firstMatch.waitForExistence(timeout: 5))
        edited.press(forDuration: 1.2)
        let selectAll = app.descendants(matching: .any).matching(NSPredicate(format: "label == 'Select All' AND (elementType == %d OR elementType == %d)", XCUIElement.ElementType.button.rawValue, XCUIElement.ElementType.menuItem.rawValue)).firstMatch
        for _ in 0..<3 where !selectAll.exists {
            let select = app.buttons["Select"].firstMatch
            let more = app.buttons["Show more items"].firstMatch
            if select.exists { select.tap() }
            else if more.exists { more.tap() }
            else { break }
        }
        attach(app, "Native source editing menu before whole-text selection")
        XCTAssertTrue(selectAll.waitForExistence(timeout: 5), "The real system Select All action must be available")
        selectAll.tap()
        attach(app, "Native whole source text selected before deletion")
        edited.typeText(XCUIKeyboardKey.delete.rawValue)
        XCTAssertEqual(edited.value as? String, "")
        app.buttons["source-edit-text-done"].tap()
        app.buttons["Save"].tap()
        XCTAssertTrue(app.buttons["Edit title, date, or working text"].waitForExistence(timeout: 5))
        for _ in 0..<12 where !app.buttons["Working text"].isHittable { app.swipeUp() }
        app.buttons["Working text"].tap()
        for _ in 0..<4 where !app.staticTexts["No text has been added."].exists { app.swipeUp() }
        XCTAssertTrue(app.staticTexts["No text has been added."].waitForExistence(timeout: 5))
        app.buttons["Original captured text"].tap()
        XCTAssertTrue(app.staticTexts["Allergy: latex\nBring records"].waitForExistence(timeout: 5))
        attach(app, "Cleared working text preserves original evidence")
    }

    @MainActor private func emptyApp() -> XCUIApplication {
        let app = XCUIApplication(); app.launchArguments = ["--uitesting", "--reset"]; app.launch()
        let start = app.buttons["Start with an empty care memory"]
        for _ in 0..<4 where !start.isHittable { app.swipeUp() }
        XCTAssertTrue(start.waitForExistence(timeout: 15)); start.tap()
        XCTAssertTrue(app.buttons["global-add"].waitForExistence(timeout: 10))
        return app
    }
    @MainActor private func attach(_ app: XCUIApplication, _ name: String) {
        let attachment = XCTAttachment(screenshot: app.screenshot()); attachment.name = name; attachment.lifetime = .keepAlways; add(attachment)
    }
    @MainActor private func scrollOuterForm(_ app: XCUIApplication) {
        let frame = app.frame
        let top = (app.navigationBars.allElementsBoundByIndex.filter(\.isHittable).map { $0.frame.maxY }.max() ?? frame.minY) + 20
        let bottom = (app.tabBars.allElementsBoundByIndex.filter(\.isHittable).map { $0.frame.minY }.min() ?? frame.maxY) - 20
        XCTAssertGreaterThan(bottom - top, 80)
        let origin = app.coordinate(withNormalizedOffset: .zero)
        let x = 12.0
        let start = origin.withOffset(CGVector(dx: x, dy: bottom - frame.minY - 20))
        let end = origin.withOffset(CGVector(dx: x, dy: top - frame.minY + 20))
        start.press(forDuration: 0.01, thenDragTo: end)
    }
}
