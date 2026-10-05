import XCTest

final class EditorDraftRecoveryUITests: XCTestCase {
    @MainActor func testReviewedPassageDirtyCancelAndSwipePreserveDraftUntilExplicitDiscard() throws {
        continueAfterFailure = false
        let app = emptyApp()
        app.buttons["global-add"].tap()
        let title = app.textFields["capture-title"]
        tap(title, in: app); title.typeText("Fictional evidence for review recovery")
        let sourceText = "Allergy: latex"
        let capture = app.textViews["capture-text"]
        tap(capture, in: app); capture.typeText(sourceText)
        app.buttons["capture-text-done"].tap()
        XCTAssertTrue(app.keyboards.firstMatch.waitForNonExistence(timeout: 5))
        tap(app.buttons["save-evidence"], in: app)
        tap(app.buttons["Review & edit"].firstMatch, in: app)
        tap(app.buttons["Choose an exact supporting passage"], in: app)
        let passage = app.textViews["claim-quote"]
        XCTAssertTrue(passage.waitForExistence(timeout: 5))
        let original = try XCTUnwrap(passage.value as? String)
        XCTAssertFalse(original.isEmpty)
        XCTAssertTrue(sourceText.contains(original))
        tap(passage, in: app); passage.typeText(" [unsaved practice wording]")
        app.buttons["claim-quote-done"].tap()
        XCTAssertTrue(app.keyboards.firstMatch.waitForNonExistence(timeout: 5))
        let draft = try XCTUnwrap(passage.value as? String)
        XCTAssertTrue(draft.contains("[unsaved practice wording]"))
        app.navigationBars["Review claim"].swipeDown()
        XCTAssertTrue(app.navigationBars["Review claim"].exists, "Native dismissal must not silently lose an edited supporting passage")
        XCTAssertEqual(passage.value as? String, draft)
        app.buttons["Cancel"].tap()
        XCTAssertTrue(app.alerts.buttons["Keep editing"].waitForExistence(timeout: 5))
        app.alerts.buttons["Keep editing"].tap()
        XCTAssertEqual(passage.value as? String, draft)
        snapshot(app, "CareInOne · reviewed passage kept after cancelled dismissal")
        app.buttons["Cancel"].tap(); app.alerts.buttons["Discard changes"].tap()
        XCTAssertTrue(app.navigationBars["Review claim"].waitForNonExistence(timeout: 5))
        tap(app.buttons["Review & edit"].firstMatch, in: app)
        tap(app.buttons["Choose an exact supporting passage"], in: app)
        XCTAssertEqual(passage.value as? String, original, "Discard must not save or accept the unsupported working edit")
        app.buttons["Cancel"].tap()
        XCTAssertTrue(app.navigationBars["Review claim"].waitForNonExistence(timeout: 5))
        XCTAssertFalse(app.alerts.buttons["Discard changes"].exists, "An unchanged review should close directly")
        tap(app.buttons["Edit title, date, or working text"], in: app, scrollDown: true)
        let workingText = app.textViews["source-edit-text"]
        tap(workingText, in: app)
        XCTAssertEqual(workingText.value as? String, sourceText)
        app.buttons["source-edit-text-done"].tap()
        app.buttons["Cancel"].tap()
    }

    @MainActor func testWorkspaceDirtyCancelSwipeDiscardAndSavedPrioritiesSurviveRelaunch() throws {
        continueAfterFailure = false
        let app = emptyApp()
        app.tabBars.buttons["Visits"].tap()
        tap(app.buttons["visits-workspaces"], in: app)
        tap(app.buttons["workspace-new"], in: app)
        let title = app.textFields["workspace-title"]
        tap(title, in: app); title.typeText("Fictional preparation")
        let priorities = app.textFields["workspace-priorities"]
        tap(priorities, in: app); priorities.typeText("Bring my written questions")
        app.buttons["Cancel"].tap()
        XCTAssertTrue(app.alerts.buttons["Keep editing"].waitForExistence(timeout: 5))
        app.alerts.buttons["Keep editing"].tap()
        XCTAssertEqual(title.value as? String, "Fictional preparation")
        XCTAssertEqual(priorities.value as? String, "Bring my written questions")
        app.buttons["Cancel"].tap(); app.alerts.buttons["Discard changes"].tap()
        XCTAssertTrue(app.navigationBars["New visit workspace"].waitForNonExistence(timeout: 5))
        XCTAssertFalse(app.staticTexts["Fictional preparation"].exists)
        tap(app.buttons["workspace-new"], in: app)
        XCTAssertEqual(title.value as? String, "Name this visit")
        tap(title, in: app); title.typeText("Fictional preparation")
        tap(priorities, in: app); priorities.typeText("Bring my written questions")
        app.buttons["workspace-save"].tap()
        XCTAssertTrue(app.navigationBars["Visit workspace"].waitForExistence(timeout: 5))
        tap(app.buttons["Edit title, encounter, or priorities"], in: app)
        XCTAssertEqual(priorities.value as? String, "Bring my written questions")
        tap(priorities, in: app); priorities.typeText(" [unsaved correction]")
        app.buttons["Cancel"].tap(); app.alerts.buttons["Keep editing"].tap()
        let draft = try XCTUnwrap(priorities.value as? String)
        XCTAssertTrue(draft.contains("[unsaved correction]"))
        let header = app.navigationBars["Edit workspace"].frame, bounds = app.frame
        let origin = app.coordinate(withNormalizedOffset: .zero)
        let start = origin.withOffset(CGVector(dx: header.midX - bounds.minX, dy: header.maxY - 8 - bounds.minY))
        let end = origin.withOffset(CGVector(dx: header.midX - bounds.minX, dy: min(bounds.maxY - 100, header.maxY + 180) - bounds.minY))
        start.press(forDuration: 0.05, thenDragTo: end)
        XCTAssertEqual(app.state, .runningForeground, "The dismissal gesture must stay inside the app, away from the status/system edge")
        XCTAssertTrue(app.navigationBars["Edit workspace"].exists)
        XCTAssertEqual(priorities.value as? String, draft)
        snapshot(app, "CareInOne · workspace priorities kept after cancelled dismissal")
        app.buttons["Cancel"].tap(); app.alerts.buttons["Discard changes"].tap()
        XCTAssertTrue(app.navigationBars["Edit workspace"].waitForNonExistence(timeout: 5))
        tap(app.buttons["Edit title, encounter, or priorities"], in: app)
        XCTAssertEqual(title.value as? String, "Fictional preparation")
        XCTAssertEqual(priorities.value as? String, "Bring my written questions")
        app.buttons["Cancel"].tap()
        XCTAssertTrue(app.navigationBars["Edit workspace"].waitForNonExistence(timeout: 5))
        XCTAssertFalse(app.alerts.buttons["Discard changes"].exists)
        app.terminate(); app.launchArguments = ["--uitesting"]; app.launch()
        XCTAssertTrue(app.tabBars.buttons["Today"].waitForExistence(timeout: 15))
        app.tabBars.buttons["Visits"].tap()
        tap(app.buttons["visits-workspaces"], in: app)
        tap(app.staticTexts["Fictional preparation"], in: app)
        tap(app.buttons["Edit title, encounter, or priorities"], in: app)
        XCTAssertEqual(title.value as? String, "Fictional preparation")
        XCTAssertEqual(priorities.value as? String, "Bring my written questions")
        app.buttons["Cancel"].tap()
    }

    @MainActor private func emptyApp() -> XCUIApplication {
        let app = XCUIApplication(); app.launchArguments = ["--uitesting", "--reset"]; app.launch()
        tap(app.buttons["Start with an empty care memory"], in: app)
        XCTAssertTrue(app.tabBars.buttons["Today"].waitForExistence(timeout: 15))
        if app.alerts.buttons["OK"].exists { app.alerts.buttons["OK"].tap() }
        return app
    }

    @MainActor private func tap(_ element: XCUIElement, in app: XCUIApplication, scrollDown: Bool = false) {
        for _ in 0..<18 where !element.isHittable {
            let bounds = app.frame
            let surfaces = app.tables.allElementsBoundByIndex + app.collectionViews.allElementsBoundByIndex + app.scrollViews.allElementsBoundByIndex
            let frames = surfaces.compactMap { surface -> CGRect? in
                guard surface.exists, surface.isHittable else { return nil }
                let frame = surface.frame
                guard frame.width > 0, frame.height > 100,
                      frame.minX >= bounds.minX - 1, frame.maxX <= bounds.maxX + 1 else { return nil }
                return frame
            }
            let frame = frames.max { $0.width * $0.height < $1.width * $1.height } ?? bounds
            let navBottom = app.navigationBars.allElementsBoundByIndex.filter(\.exists).map { $0.frame.maxY }.max() ?? frame.minY
            let tabTop = app.tabBars.allElementsBoundByIndex.filter(\.exists).map { $0.frame.minY }.min() ?? frame.maxY
            let keyboardTop = app.keyboards.firstMatch.exists ? app.keyboards.firstMatch.frame.minY : frame.maxY
            let top = max(frame.minY, navBottom) + 16
            let bottom = min(frame.maxY, min(tabTop, keyboardTop)) - 16
            guard bottom - top > 50 else { XCTFail("No visible content region is available"); return }
            let origin = app.coordinate(withNormalizedOffset: .zero)
            let high = top + (bottom - top) * 0.2 - bounds.minY
            let low = top + (bottom - top) * 0.8 - bounds.minY
            let start = origin.withOffset(CGVector(dx: frame.midX - bounds.minX, dy: scrollDown ? high : low))
            let end = origin.withOffset(CGVector(dx: frame.midX - bounds.minX, dy: scrollDown ? low : high))
            start.press(forDuration: 0.01, thenDragTo: end)
        }
        XCTAssertTrue(element.waitForExistence(timeout: 5)); XCTAssertTrue(element.isHittable); element.tap()
    }

    @MainActor private func snapshot(_ app: XCUIApplication, _ name: String) {
        let attachment = XCTAttachment(screenshot: app.screenshot()); attachment.name = name; attachment.lifetime = .keepAlways; add(attachment)
    }
}
