import XCTest

final class PatientCompanionUITests: XCTestCase {
    @MainActor func testEmptyPatientAppointmentBriefAnswersResumeAndReview() throws {
        continueAfterFailure = false
        let app = launch(demo: false)
        tap(app.buttons["today-companion"], in: app)
        tap(app.buttons["companion-edit-opening"], in: app)
        let opening = app.textViews["companion-opening-editor"]
        XCTAssertTrue(opening.waitForExistence(timeout: 5)); opening.tap(); opening.typeText("I want to leave knowing what happens next.")
        app.buttons["companion-opening-save"].tap()
        tap(app.buttons["companion-show-brief"], in: app, direction: .down)
        XCTAssertTrue(app.staticTexts["companion-brief-text"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["companion-brief-text"].label.contains("I want to leave knowing what happens next."))
        snapshot(app, "CareInOne · my short opening brief")
        tap(app.buttons["companion-brief-pdf"], in: app)
        XCTAssertTrue(app.buttons["Share brief PDF"].waitForExistence(timeout: 10))
        app.buttons["Done"].tap()
        tap(app.buttons["companion-start-live"], in: app, direction: .down)
        let answer = app.textViews["companion-live-answer"]
        XCTAssertTrue(answer.waitForExistence(timeout: 5)); answer.tap(); answer.typeText("Allergy: latex")
        tap(app.buttons["companion-save-answer"], in: app)
        tap(app.buttons["companion-next"], in: app)
        let secondQuestion = app.staticTexts["companion-live-question"].label
        app.terminate(); app.launchArguments = ["--uitesting"]; app.launch()
        tap(app.buttons["today-companion"], in: app)
        tap(app.buttons["companion-start-live"], in: app)
        XCTAssertEqual(app.staticTexts["companion-live-question"].label, secondQuestion)
        tap(app.buttons["Previous"], in: app)
        XCTAssertTrue((answer.value as? String)?.contains("Allergy: latex") == true)
        snapshot(app, "CareInOne · a saved answer during my appointment")
        app.buttons["companion-finish"].tap()
        tap(app.buttons["companion-capture-answers"], in: app)
        tap(app.buttons["Review & edit"].firstMatch, in: app)
        let confirm = app.switches["This accurately reflects what was reported"]
        reveal(confirm, in: app)
        confirm.coordinate(withNormalizedOffset: CGVector(dx: 0.93, dy: 0.5)).tap()
        XCTAssertEqual(confirm.value as? String, "1", "The report must be explicitly confirmed before acceptance")
        let accept = app.buttons["accept-claim"]
        reveal(accept, in: app)
        // A partially clipped Form footer can report hittable while its tap is lost.
        scrollContent(in: app, direction: .up)
        XCTAssertTrue(accept.isEnabled); accept.tap()
        XCTAssertTrue(app.buttons["accept-claim"].waitForNonExistence(timeout: 5))
        app.tabBars.buttons["My Care"].tap(); app.staticTexts["Allergies"].tap()
        XCTAssertTrue(app.staticTexts["latex"].waitForExistence(timeout: 5))
    }

    @MainActor func testFollowThroughMessageOutreachReplyPersistsAndNeedsReview() throws {
        continueAfterFailure = false
        let app = launch(demo: true)
        openFirstHelper(app)
        tap(app.buttons["assist-obstacle-waiting"], in: app)
        let message = app.textViews["assist-message"]
        XCTAssertTrue(message.waitForExistence(timeout: 5))
        XCTAssertTrue((message.value as? String)?.contains("current status") == true)
        snapshot(app, "CareInOne · the words to move care forward")
        app.segmentedControls["assist-section"].buttons["Replies & progress"].tap()
        let note = app.textFields["assist-attempt-note"]
        reveal(note, in: app); note.tap(); note.typeText("Synthetic call: asked the office for an update.")
        XCTAssertTrue((note.value as? String)?.contains("Synthetic call: asked the office for an update.") == true)
        let done = app.buttons["assist-editing-done"]
        XCTAssertTrue(done.waitForExistence(timeout: 5)); done.tap()
        XCTAssertEqual(app.keyboards.count, 0)
        tap(app.buttons["assist-record-contacted"], in: app)
        XCTAssertTrue(app.staticTexts["Synthetic call: asked the office for an update."].waitForExistence(timeout: 5))
        let reply = app.textViews["assist-reply-draft"]
        reveal(reply, in: app, direction: .down); reply.tap(); reply.typeText("Allergy: latex")
        let replyDone = app.buttons["assist-reply-draft-done"]
        XCTAssertTrue(replyDone.waitForExistence(timeout: 5)); replyDone.tap()
        XCTAssertEqual(app.keyboards.count, 0)
        tap(app.segmentedControls["assist-section"].buttons["My next step"], in: app, direction: .down)
        app.terminate(); app.launchArguments = ["--uitesting"]; app.launch()
        XCTAssertTrue(app.tabBars.buttons["Today"].waitForExistence(timeout: 10))
        XCTAssertFalse(app.buttons["exit-demo"].exists, "Ordinary relaunch opens the personal workspace")
        XCTAssertFalse(app.staticTexts["Synthetic call: asked the office for an update."].exists, "Fictional outreach must remain outside the personal patient history")
        reopenIsolatedDemo(app)
        openFirstHelper(app)
        app.segmentedControls["assist-section"].buttons["Replies & progress"].tap()
        reveal(app.staticTexts["Synthetic call: asked the office for an update."], in: app)
        XCTAssertTrue(app.staticTexts["Synthetic call: asked the office for an update."].exists, "Recorded outreach survives reopening the isolated demo")
        reveal(reply, in: app, direction: .down)
        XCTAssertTrue((reply.value as? String)?.contains("Allergy: latex") == true)
        snapshot(app, "CareInOne · saved outreach and clinic reply")
        tap(app.buttons["assist-save-reply"], in: app)
        let review = app.buttons["Review & edit"].firstMatch
        reveal(review, in: app)
        XCTAssertTrue(review.exists)
        XCTAssertTrue(app.staticTexts["Synthetic demo"].exists)
        // Returning from source deletion must not expose a cached reply or outgoing copy.
        tap(app.buttons["Delete source and its claims"], in: app)
        // XCTest reports a partially clipped List footer as hittable on iOS 18.
        // Bring the destructive action fully above the sheet's bottom edge.
        scrollContent(in: app, direction: .up)
        tap(app.buttons["impact-delete"], in: app)
        XCTAssertTrue(app.buttons["Delete source"].waitForExistence(timeout: 5))
        app.buttons["Delete source"].tap()
        XCTAssertTrue(app.navigationBars["Source evidence"].waitForNonExistence(timeout: 5))
        XCTAssertFalse(app.staticTexts["Synthetic call: asked the office for an update."].exists)
        if reply.exists { XCTAssertFalse((reply.value as? String)?.contains("Allergy: latex") == true) }
    }

    @MainActor func testAppointmentCompanionAtAccessibilityTextSize() throws {
        continueAfterFailure = false
        let app = launch(demo: true, accessibility: true)
        tap(app.buttons["today-companion"], in: app)
        tap(app.buttons["companion-start-live"], in: app)
        XCTAssertTrue(app.staticTexts["companion-live-question"].waitForExistence(timeout: 5))
        snapshot(app, "CareInOne · appointment question at accessibility size")
        tap(app.buttons["companion-pause"], in: app, direction: .down)
        app.tabBars.buttons["Today"].tap()
        // A tab retains its path; return to the Today root first.
        if app.navigationBars["My appointment"].exists { app.navigationBars.buttons.element(boundBy: 0).tap() }
        tap(app.staticTexts["Follow-through"].firstMatch, in: app, direction: .down)
        let helper = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH 'loop-help-'")).firstMatch
        tap(helper, in: app)
        tap(app.segmentedControls["assist-section"].buttons["Replies & progress"], in: app)
        reveal(app.buttons["assist-record-contacted"], in: app)
        snapshot(app, "CareInOne · getting unstuck at accessibility size")
    }

    @MainActor func testVisitSourceContextOpensInsideTheConversationAndRetainsAnswer() throws {
        continueAfterFailure = false
        let app = launch(demo: true)
        tap(app.buttons["today-companion"], in: app)
        tap(app.buttons["companion-start-live"], in: app)
        let answer = app.textViews["companion-live-answer"]
        XCTAssertTrue(answer.waitForExistence(timeout: 5))
        answer.tap(); answer.typeText("Synthetic visit answer: I asked for a written clarification.")
        tap(app.buttons["Saved context for this question"], in: app)
        tap(app.buttons["companion-context-source"].firstMatch, in: app)
        XCTAssertTrue(app.navigationBars["Source evidence"].waitForExistence(timeout: 5))
        app.navigationBars.buttons.element(boundBy: 0).tap()
        reveal(answer, in: app, direction: .down)
        XCTAssertTrue((answer.value as? String)?.contains("Synthetic visit answer: I asked for a written clarification.") == true)
        tap(app.buttons["companion-pause"], in: app, direction: .down)
        XCTAssertTrue(app.navigationBars["My appointment"].waitForExistence(timeout: 5))
    }

    private enum Direction { case up, down }
    @MainActor private func launch(demo: Bool, accessibility: Bool = false) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["--uitesting", "--reset"] + (demo ? ["--demo"] : []) + (accessibility ? ["-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityXXXL"] : [])
        app.launch()
        if !demo { tap(app.buttons["Start with an empty care memory"], in: app) }
        XCTAssertTrue(app.tabBars.buttons["Today"].waitForExistence(timeout: 20))
        if app.alerts.buttons["OK"].exists { app.alerts.buttons["OK"].tap() }
        return app
    }
    @MainActor private func openFirstHelper(_ app: XCUIApplication) {
        tap(app.staticTexts["Follow-through"].firstMatch, in: app, direction: .down)
        tap(app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH 'loop-help-'")).firstMatch, in: app)
        XCTAssertTrue(app.staticTexts["assist-title"].waitForExistence(timeout: 5))
    }
    @MainActor private func reopenIsolatedDemo(_ app: XCUIApplication) {
        let settings = app.tabBars.buttons["Settings"]
        XCTAssertTrue(settings.waitForExistence(timeout: 10)); settings.tap()
        tap(app.buttons["open-demo"], in: app)
        XCTAssertTrue(app.buttons["exit-demo"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.tabBars.buttons["Today"].waitForExistence(timeout: 10)); app.tabBars.buttons["Today"].tap()
    }
    @MainActor private func reveal(_ element: XCUIElement, in app: XCUIApplication, direction: Direction = .up) {
        for _ in 0..<16 where !element.isHittable { scrollContent(in: app, direction: direction) }
        XCTAssertTrue(element.waitForExistence(timeout: 10))
        XCTAssertTrue(element.isHittable)
    }
    @MainActor private func scrollContent(in app: XCUIApplication, direction: Direction) {
        // The isolated demo banner is outside the screen's scrolling content.
        // XCTest's app-wide swipe can land on that banner or the tab bar instead.
        // During a SwiftUI push, an outgoing List can disappear. Read each
        // candidate's geometry once, discard offscreen transition surfaces,
        // and sort immutable rectangles instead of resolving lazy elements
        // repeatedly inside filter/max closures.
        let appFrame = app.frame
        let containers = app.tables.allElementsBoundByIndex + app.collectionViews.allElementsBoundByIndex + app.scrollViews.allElementsBoundByIndex
        let frames = containers.compactMap { element -> CGRect? in
            guard element.exists, element.isHittable else { return nil }
            let candidate = element.frame
            guard candidate.width > 0, candidate.height > 100,
                  candidate.minX >= appFrame.minX - 1,
                  candidate.maxX <= appFrame.maxX + 1 else { return nil }
            return candidate
        }
        let frame = frames.max { $0.width * $0.height < $1.width * $1.height } ?? appFrame
        let navigationBottom = app.navigationBars.allElementsBoundByIndex.filter(\.isHittable).map { $0.frame.maxY }.max() ?? frame.minY
        let demoBottom = app.buttons["exit-demo"].exists ? app.buttons["exit-demo"].frame.maxY : frame.minY
        let tabTop = app.tabBars.allElementsBoundByIndex.filter(\.isHittable).map { $0.frame.minY }.min() ?? frame.maxY
        let keyboardTop = app.keyboards.firstMatch.exists ? app.keyboards.firstMatch.frame.minY : frame.maxY
        let top = max(frame.minY, max(navigationBottom, demoBottom)) + 16
        let bottom = min(frame.maxY, min(tabTop, keyboardTop)) - 16
        guard frame.width > 0, frame.height > 0, bottom - top > 50 else {
            XCTFail("No usable scrolling content is visible above the keyboard and tab bar")
            return
        }
        let high = top + (bottom - top) * 0.2
        let low = top + (bottom - top) * 0.8
        let startY = direction == .up ? low : high
        let endY = direction == .up ? high : low
        // The gesture stays inside visible content, below the demo banner and
        // navigation bar and above the keyboard/tab bar.
        let x = max(appFrame.minX + 20, min(frame.midX, appFrame.maxX - 20))
        let origin = app.coordinate(withNormalizedOffset: .zero)
        let start = origin.withOffset(CGVector(dx: x - appFrame.minX, dy: startY - appFrame.minY))
        let end = origin.withOffset(CGVector(dx: x - appFrame.minX, dy: endY - appFrame.minY))
        start.press(forDuration: 0.01, thenDragTo: end)
    }
    @MainActor private func tap(_ element: XCUIElement, in app: XCUIApplication, direction: Direction = .up) { reveal(element, in: app, direction: direction); element.tap() }
    @MainActor private func snapshot(_ app: XCUIApplication, _ name: String) {
        let attachment = XCTAttachment(screenshot: app.screenshot()); attachment.name = name; attachment.lifetime = .keepAlways; add(attachment)
    }
}
