import XCTest

final class FollowThroughDraftRecoveryUITests: XCTestCase {
    /// This suite intentionally resets its temporary fixture workspace. Use a disposable simulator only.
    @MainActor func testResolutionNoteDoneSwipeAndSourceNavigationRequireExplicitDiscard() throws {
        continueAfterFailure = false
        let app = demoApp()
        tap(app.buttons.matching(NSPredicate(format: "label CONTAINS[c] 'To clarify'")).firstMatch, in: app)
        XCTAssertTrue(app.navigationBars["Records to Clarify"].waitForExistence(timeout: 10))
        let discrepancy = app.buttons.matching(NSPredicate(format: "label BEGINSWITH 'Metoprolol succinate:' AND label CONTAINS 'Compare 2 source-linked reports'")).firstMatch
        tap(discrepancy, in: app)
        // Confirm the actual modal opened before scrolling; otherwise a tap on
        // the underlying clarification list could masquerade as missing input.
        XCTAssertTrue(app.navigationBars["Compare sources"].waitForExistence(timeout: 10))
        let note = app.descendants(matching: .any).matching(identifier: "conflict-resolution-note").firstMatch
        tap(note, in: app); note.typeText("Fictional draft to bring to my care team")
        app.buttons["conflict-resolution-note-done"].tap()
        XCTAssertTrue(app.keyboards.firstMatch.waitForNonExistence(timeout: 5))
        let draft = try XCTUnwrap(note.value as? String)
        app.navigationBars["Compare sources"].swipeDown()
        XCTAssertTrue(app.navigationBars["Compare sources"].exists)
        XCTAssertEqual(note.value as? String, draft)
        app.buttons["Done"].tap()
        XCTAssertTrue(app.alerts.buttons["Keep editing"].waitForExistence(timeout: 5))
        app.alerts.buttons["Keep editing"].tap()
        XCTAssertEqual(note.value as? String, draft)

        // Opening supporting evidence and returning must not reinitialize an unsaved note.
        tap(app.buttons["Synthetic · PCP medication list"].firstMatch, in: app, up: false)
        XCTAssertTrue(app.navigationBars["Source evidence"].waitForExistence(timeout: 5))
        app.navigationBars["Source evidence"].buttons.firstMatch.tap()
        XCTAssertTrue(app.navigationBars["Compare sources"].waitForExistence(timeout: 5))
        tap(note, in: app); app.buttons["conflict-resolution-note-done"].tap()
        XCTAssertEqual(note.value as? String, draft)
        snapshot(app, "CareInOne · clarification note kept after cancelled dismissal")
        app.buttons["Done"].tap(); app.alerts.buttons["Discard changes"].tap()
        XCTAssertTrue(app.navigationBars["Compare sources"].waitForNonExistence(timeout: 5))
        tap(discrepancy, in: app); tap(note, in: app)
        let restoredNote = try XCTUnwrap(note.value as? String)
        XCTAssertEqual(note.placeholderValue, "Your resolution note")
        XCTAssertTrue(restoredNote.isEmpty || restoredNote == note.placeholderValue, "Discard must leave the saved note empty; native TextField exposes either empty value or its placeholder across supported OS versions")
        app.buttons["conflict-resolution-note-done"].tap()
        app.buttons["Done"].tap()
        XCTAssertTrue(app.navigationBars["Compare sources"].waitForNonExistence(timeout: 5))
        XCTAssertFalse(app.alerts.buttons["Discard changes"].exists)
        XCTAssertTrue(discrepancy.exists, "Discard does not clarify or dismiss either report")
    }

    @MainActor func testLoopNoteDateAndPrecisionKeepDiscardSaveAndRelaunch() throws {
        continueAfterFailure = false
        let app = demoApp(); app.tabBars.buttons["My Care"].tap()
        tap(app.buttons["Follow-through"], in: app)
        let cbc = app.buttons.matching(NSPredicate(format: "label BEGINSWITH 'CBC'")).firstMatch
        tap(cbc, in: app)
        let note = app.textFields["loop-update-note"]
        tap(note, in: app); note.typeText("Fictional draft scheduling note")
        app.buttons["loop-update-note-done"].tap()
        let due = app.switches["Due date is known"]
        XCTAssertTrue(due.waitForExistence(timeout: 5)); XCTAssertEqual(due.value as? String, "1")
        // SwiftUI exposes the full labelled row as the Switch; its center can hit the label.
        due.coordinate(withNormalizedOffset: CGVector(dx: 0.93, dy: 0.5)).tap()
        let turnedOff = XCTNSPredicateExpectation(predicate: NSPredicate(format: "value == '0'"), object: due)
        XCTAssertEqual(XCTWaiter.wait(for: [turnedOff], timeout: 5), .completed)
        let precision = app.buttons["loop-update-precision"]
        tap(precision, in: app); tap(app.buttons["Approximate"], in: app)
        snapshot(app, "CareInOne · fictional precision after menu selection")
        XCTAssertTrue(pickerSelection(precision).localizedCaseInsensitiveContains("approximate"))
        app.navigationBars["Follow-through detail"].swipeDown()
        XCTAssertTrue(app.navigationBars["Follow-through detail"].exists)
        app.buttons["Done"].tap(); app.alerts.buttons["Keep editing"].tap()
        XCTAssertEqual(note.value as? String, "Fictional draft scheduling note")
        XCTAssertEqual(due.value as? String, "0")
        XCTAssertTrue(pickerSelection(precision).localizedCaseInsensitiveContains("approximate"))
        snapshot(app, "CareInOne · follow-through edits kept after cancelled dismissal")
        app.buttons["Done"].tap(); app.alerts.buttons["Discard changes"].tap()
        XCTAssertTrue(app.navigationBars["Follow-through detail"].waitForNonExistence(timeout: 5))
        tap(cbc, in: app); tap(note, in: app)
        XCTAssertEqual(note.value as? String, "Notes")
        app.buttons["loop-update-note-done"].tap()
        XCTAssertEqual(due.value as? String, "1")
        XCTAssertTrue(pickerSelection(precision).localizedCaseInsensitiveContains("exact"))
        tap(note, in: app); note.typeText("Fictional saved scheduling note")
        app.buttons["loop-update-note-done"].tap(); tap(app.buttons["loop-update-save"], in: app)
        XCTAssertTrue(app.navigationBars["Follow-through detail"].waitForNonExistence(timeout: 5))
        app.terminate(); app.launchArguments = ["--uitesting", "--demo"]; app.launch()
        XCTAssertTrue(app.tabBars.buttons["Today"].waitForExistence(timeout: 20)); app.tabBars.buttons["My Care"].tap()
        tap(app.buttons["Follow-through"], in: app); tap(cbc, in: app); tap(note, in: app)
        XCTAssertEqual(note.value as? String, "Fictional saved scheduling note")
        app.buttons["loop-update-note-done"].tap()
        XCTAssertEqual(due.value as? String, "1")
        XCTAssertTrue(pickerSelection(precision).localizedCaseInsensitiveContains("exact"))
        app.buttons["Done"].tap()
        XCTAssertTrue(app.navigationBars["Follow-through detail"].waitForNonExistence(timeout: 5))
        XCTAssertFalse(app.alerts.buttons["Discard changes"].exists)
    }

    @MainActor private func demoApp() -> XCUIApplication {
        let app = XCUIApplication(); app.launchArguments = ["--uitesting", "--reset", "--demo"]; app.launch()
        XCTAssertTrue(app.tabBars.buttons["Today"].waitForExistence(timeout: 20))
        if app.alerts.buttons["OK"].exists { app.alerts.buttons["OK"].tap() }
        app.tabBars.buttons["Today"].tap(); return app
    }
    @MainActor private func tap(_ element: XCUIElement, in app: XCUIApplication, up: Bool = true) {
        let beganInComparison = app.navigationBars["Compare sources"].exists
        for _ in 0..<18 where !element.isHittable {
            if beganInComparison {
                guard app.navigationBars["Compare sources"].exists else { XCTFail("The comparison must remain open while revealing its draft field"); return }
            }
            let frame = app.frame
            let navBottom = app.navigationBars.allElementsBoundByIndex.filter(\.exists).map { $0.frame.maxY }.max() ?? frame.minY
            let tabTop = app.tabBars.allElementsBoundByIndex.filter(\.exists).map { $0.frame.minY }.min() ?? frame.maxY
            let keyboardTop = app.keyboards.firstMatch.exists ? app.keyboards.firstMatch.frame.minY : frame.maxY
            let top = max(frame.minY + 135, navBottom + 25), bottom = min(tabTop, keyboardTop) - 45
            guard bottom > top + 50 else { XCTFail("No visible content area"); return }
            // A presented conflict detail has its own ScrollView. Drag that
            // visible content rather than relying on the underlying tab frame.
            let content = app.navigationBars["Compare sources"].exists ? app.scrollViews.allElementsBoundByIndex.last : nil
            let visible = (content?.frame ?? frame).intersection(CGRect(x: frame.minX, y: top, width: frame.width, height: bottom - top))
            guard !visible.isEmpty else { XCTFail("No visible scroll content"); return }
            let origin = app.coordinate(withNormalizedOffset: .zero)
            // Use the visible scroll view edge, outside source-link labels. A
            // near-instant mid-row gesture can be interpreted as a link tap.
            let x = visible.minX + 12
            let start = origin.withOffset(CGVector(dx: x, dy: visible.minY + visible.height * (up ? 0.85 : 0.15)))
            let end = origin.withOffset(CGVector(dx: x, dy: visible.minY + visible.height * (up ? 0.15 : 0.85)))
            start.press(forDuration: 0.2, thenDragTo: end)
        }
        XCTAssertTrue(element.waitForExistence(timeout: 5)); XCTAssertTrue(element.isHittable); element.tap()
    }
    @MainActor private func pickerSelection(_ picker: XCUIElement) -> String {
        picker.label + " " + (picker.value as? String ?? "") + " " + picker.staticTexts.allElementsBoundByIndex.map(\.label).joined(separator: " ")
    }
    @MainActor private func snapshot(_ app: XCUIApplication, _ name: String) {
        let attachment = XCTAttachment(screenshot: app.screenshot()); attachment.name = name; attachment.lifetime = .keepAlways; add(attachment)
    }
}
