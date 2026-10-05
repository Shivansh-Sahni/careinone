import XCTest
import UIKit

final class EditorRecoveryUITests: XCTestCase {
    @MainActor func testPersonalNoteDiscardPreservesSavedMultilineContentAfterRelaunch() throws {
        continueAfterFailure = false
        let app = emptyApp()
        openNotes(app)
        tap(app.buttons["Write a personal note"], in: app)
        let original = "My fictional questions 🫶🏽\n" + (1...30).map { "Item \($0): bring the written records." }.joined(separator: "\n")
        paste(original, into: "personal-note-text", in: app)
        tap(app.buttons["Save changes"], in: app)
        tap(app.buttons["Edit note"].firstMatch, in: app)
        let editor = app.textViews["personal-note-text"]
        XCTAssertEqual(editor.value as? String, original)
        tap(editor, in: app); editor.typeText("Unsaved correction")
        tapKeyboardDone("personal-note-text-done", in: app)
        XCTAssertTrue(app.keyboards.firstMatch.waitForNonExistence(timeout: 5))
        app.buttons["Cancel"].tap()
        XCTAssertTrue(app.buttons["Discard changes"].waitForExistence(timeout: 5))
        app.alerts.buttons["Keep editing"].tap()
        XCTAssertTrue((editor.value as? String)?.contains("Unsaved correction") == true)
        app.buttons["Cancel"].tap(); app.buttons["Discard changes"].tap()
        XCTAssertTrue(app.navigationBars["Edit note"].waitForNonExistence(timeout: 5))
        app.terminate(); app.launchArguments = ["--uitesting"]; app.launch()
        XCTAssertTrue(app.tabBars.buttons["My Care"].waitForExistence(timeout: 15))
        openNotes(app); tap(app.buttons["Edit note"].firstMatch, in: app)
        XCTAssertEqual(app.textViews["personal-note-text"].value as? String, original)
        app.buttons["Cancel"].tap()
        XCTAssertTrue(app.navigationBars["Edit note"].waitForNonExistence(timeout: 5))
    }

    @MainActor func testQuestionAnswerSwipeAndCancelKeepInputThenDiscardWithoutSaving() throws {
        continueAfterFailure = false
        let app = emptyApp()
        app.tabBars.buttons["My Care"].tap()
        tap(app.buttons["Questions"], in: app)
        let question = app.textFields["What do you want to ask?"]
        tap(question, in: app); question.typeText("What should I bring to my fictional visit?")
        tap(app.buttons["Save question"], in: app)
        XCTAssertTrue(app.alerts.staticTexts["Question saved."].waitForExistence(timeout: 5))
        app.alerts.buttons["OK"].tap()
        tap(app.buttons["Add an answer or edit"].firstMatch, in: app)
        let answer = "Fictional answer\nBring my notes and questions 🫶🏽."
        paste(answer, into: "question-edit-answer", in: app)
        let editor = app.textViews["question-edit-answer"]
        app.navigationBars["Your question"].swipeDown()
        XCTAssertTrue(app.navigationBars["Your question"].exists)
        XCTAssertEqual(editor.value as? String, answer)
        app.buttons["Cancel"].tap()
        XCTAssertTrue(app.alerts.buttons["Keep editing"].waitForExistence(timeout: 5))
        app.alerts.buttons["Keep editing"].tap()
        XCTAssertEqual(editor.value as? String, answer)
        app.buttons["Cancel"].tap(); app.buttons["Discard changes"].tap()
        XCTAssertTrue(app.navigationBars["Your question"].waitForNonExistence(timeout: 5))
        tap(app.buttons["Add an answer or edit"].firstMatch, in: app)
        XCTAssertEqual(app.textViews["question-edit-answer"].value as? String, "")
        paste(answer, into: "question-edit-answer", in: app)
        tap(app.buttons["question-edit-save"], in: app)
        XCTAssertTrue(app.staticTexts[answer].waitForExistence(timeout: 5))
        app.terminate(); app.launchArguments = ["--uitesting"]; app.launch()
        XCTAssertTrue(app.tabBars.buttons["My Care"].waitForExistence(timeout: 15))
        app.tabBars.buttons["My Care"].tap(); tap(app.buttons["Questions"], in: app)
        XCTAssertTrue(app.staticTexts[answer].waitForExistence(timeout: 5))
        tap(app.buttons["Delete question"].firstMatch, in: app)
        XCTAssertTrue(app.alerts.buttons["Keep question"].waitForExistence(timeout: 5))
        app.alerts.buttons["Keep question"].tap()
        XCTAssertTrue(app.staticTexts[answer].exists)
        tap(app.buttons["Delete question"].firstMatch, in: app)
        XCTAssertTrue(app.alerts.buttons["Delete question permanently"].waitForExistence(timeout: 5))
        app.alerts.buttons["Delete question permanently"].tap()
        XCTAssertTrue(app.staticTexts[answer].waitForNonExistence(timeout: 5))
        XCTAssertFalse(app.staticTexts["What should I bring to my fictional visit?"].exists)
        app.terminate(); app.launchArguments = ["--uitesting"]; app.launch()
        XCTAssertTrue(app.tabBars.buttons["My Care"].waitForExistence(timeout: 15))
        app.tabBars.buttons["My Care"].tap(); tap(app.buttons["Questions"], in: app)
        XCTAssertFalse(app.staticTexts[answer].exists)
        XCTAssertFalse(app.staticTexts["What should I bring to my fictional visit?"].exists)
    }

    @MainActor func testEncounterDiscardLeavesExistingGroupingAndCleanCancelCloses() throws {
        continueAfterFailure = false
        let app = emptyApp()
        app.tabBars.buttons["Visits"].tap()
        tap(app.buttons["Add an encounter"], in: app)
        let title = app.textFields["encounter-edit-title"]
        tap(title, in: app); title.typeText("Fictional planning visit")
        let provider = app.textFields["encounter-edit-provider"]
        tap(provider, in: app); provider.typeText("Fictional practice")
        tapKeyboardDone("encounter-edit-done", in: app)
        XCTAssertTrue(app.keyboards.firstMatch.waitForNonExistence(timeout: 5))
        tap(app.buttons["encounter-edit-save"], in: app)
        tap(app.staticTexts["Fictional planning visit"], in: app)
        tap(app.buttons["Edit encounter details"], in: app)
        tap(provider, in: app); provider.typeText("Unsaved office correction")
        tapKeyboardDone("encounter-edit-done", in: app)
        app.buttons["Cancel"].tap()
        XCTAssertTrue(app.alerts.buttons["Keep editing"].waitForExistence(timeout: 5))
        app.alerts.buttons["Keep editing"].tap()
        XCTAssertTrue((provider.value as? String)?.contains("Unsaved office correction") == true)
        app.buttons["Cancel"].tap(); app.buttons["Discard changes"].tap()
        XCTAssertTrue(app.textFields["encounter-edit-title"].waitForNonExistence(timeout: 5))
        tap(app.buttons["Edit encounter details"], in: app)
        XCTAssertEqual(app.textFields["encounter-edit-title"].value as? String, "Fictional planning visit")
        XCTAssertEqual(provider.value as? String, "Fictional practice")
        app.buttons["Cancel"].tap()
        XCTAssertTrue(app.navigationBars["Edit encounter"].waitForNonExistence(timeout: 5))
        XCTAssertFalse(app.buttons["Discard changes"].exists)
    }

    @MainActor private func emptyApp() -> XCUIApplication {
        let app = XCUIApplication(); app.launchArguments = ["--uitesting", "--reset"]; app.launch()
        tap(app.buttons["Start with an empty care memory"], in: app)
        XCTAssertTrue(app.tabBars.buttons["Today"].waitForExistence(timeout: 20))
        if app.alerts.buttons["OK"].exists { app.alerts.buttons["OK"].tap() }
        return app
    }

    @MainActor private func openNotes(_ app: XCUIApplication) {
        app.tabBars.buttons["My Care"].tap()
        tap(app.buttons["Personal notes"], in: app)
    }

    @MainActor private func paste(_ text: String, into identifier: String, in app: XCUIApplication) {
        UIPasteboard.general.string = text
        tap(app.buttons[identifier + "-paste"], in: app)
        if app.alerts.buttons["Allow Paste"].exists { app.alerts.buttons["Allow Paste"].tap() }
        XCTAssertTrue(app.textViews[identifier].waitForExistence(timeout: 5))
        XCTAssertEqual(app.textViews[identifier].value as? String, text)
    }

    @MainActor private func tap(_ element: XCUIElement, in app: XCUIApplication) {
        for _ in 0..<14 {
            if element.exists && element.isHittable { break }
            let appFrame = app.frame
            let containers = app.tables.allElementsBoundByIndex + app.collectionViews.allElementsBoundByIndex + app.scrollViews.allElementsBoundByIndex
            // Lazy SwiftUI collections can disappear between repeated frame queries.
            // Measure each visible surface once, then compare only stable rectangles.
            let frames = containers.compactMap { container -> CGRect? in
                guard container.exists, container.isHittable,
                      let frame = visibleFrame(container, within: appFrame), frame.height > 100,
                      frame.minX >= appFrame.minX - 1, frame.maxX <= appFrame.maxX + 1 else { return nil }
                return frame
            }
            let frame = frames.max { $0.width * $0.height < $1.width * $1.height } ?? appFrame
            // Bars bound the gesture; they are not tap targets. During sheet transitions
            // XCUITest can expose a bar with no activation point, so inspect only valid frames.
            let navigationBottom = app.navigationBars.allElementsBoundByIndex.compactMap { visibleFrame($0, within: app.frame) }.map(\.maxY).max() ?? frame.minY
            let tabTop = app.tabBars.allElementsBoundByIndex.compactMap { visibleFrame($0, within: app.frame) }.map(\.minY).min() ?? frame.maxY
            let keyboardTop = app.keyboards.firstMatch.exists ? app.keyboards.firstMatch.frame.minY : frame.maxY
            let top = max(frame.minY, navigationBottom) + 16
            let bottom = min(frame.maxY, min(tabTop, keyboardTop)) - 16
            guard frame.width > 0, bottom - top > 50 else { XCTFail("No content region is available above system bars or keyboard"); return }
            let origin = app.coordinate(withNormalizedOffset: .zero)
            let start = origin.withOffset(CGVector(dx: frame.midX, dy: top + (bottom - top) * 0.8))
            let end = origin.withOffset(CGVector(dx: frame.midX, dy: top + (bottom - top) * 0.2))
            start.press(forDuration: 0.05, thenDragTo: end)
        }
        XCTAssertTrue(element.waitForExistence(timeout: 5))
        XCTAssertTrue(element.isHittable)
        element.tap()
    }

    @MainActor private func tapKeyboardDone(_ identifier: String, in app: XCUIApplication) {
        let done = app.buttons[identifier]
        // A keyboard toolbar is already outside the form's scrolling content.
        // Native tap waits for its activation point without moving the long editor
        // and accidentally dismissing/replacing the toolbar we are verifying.
        XCTAssertTrue(done.waitForExistence(timeout: 5))
        done.tap()
    }

    @MainActor private func visibleFrame(_ element: XCUIElement, within bounds: CGRect) -> CGRect? {
        guard element.exists else { return nil }
        let frame = element.frame
        guard frame.minX.isFinite, frame.minY.isFinite, frame.width.isFinite, frame.height.isFinite,
              frame.width > 0, frame.height > 0, !frame.intersection(bounds).isNull else { return nil }
        return frame
    }
}
