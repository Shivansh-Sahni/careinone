import XCTest

/// Captures real production UI on explicitly disposable App Store screenshot devices.
/// It uses normal onboarding and the isolated fictional demo, never a debug seed flag.
final class ReleaseScreenshotsUITests: XCTestCase {
    @MainActor func testCaptureFictionalReleaseScreens() throws {
#if DEBUG
        throw XCTSkip("Run only this case in Release on a disposable screenshot device.")
#else
        continueAfterFailure = false
        let app = XCUIApplication(); app.launch()
        XCTAssertTrue(app.wait(for: .runningForeground, timeout: 20))
        let onboarding = app.buttons["load-demo"]
        if app.buttons["exit-demo"].waitForExistence(timeout: 2) {
            // A prior normal capture may have left the isolated demo open.
        } else if onboarding.waitForExistence(timeout: 3) {
            reveal(onboarding, in: app); onboarding.tap()
        } else {
            selectTab("Settings", in: app)
            let demo = app.buttons["open-demo"]
            reveal(demo, in: app); demo.tap()
        }
        XCTAssertTrue(app.buttons["exit-demo"].waitForExistence(timeout: 10))
        selectTab("Today", in: app)
        capture(app, "01-today")

        app.buttons["global-add"].tap()
        let title = app.textFields["capture-title"]
        XCTAssertTrue(title.waitForExistence(timeout: 5)); title.tap(); title.typeText("Fictional review sample")
        let text = app.textViews["capture-text"]
        let passage = "Allergy: latex\nFictional demonstration reference " + UUID().uuidString
        reveal(text, in: app); text.tap(); text.typeText(passage)
        XCTAssertEqual(text.value as? String, passage)
        let done = app.buttons["capture-text-done"]
        XCTAssertTrue(done.waitForExistence(timeout: 5)); done.tap()
        let save = app.buttons["save-evidence"]
        reveal(save, in: app); XCTAssertTrue(save.isEnabled); save.tap()
        // Repeating this normal capture preserves the original instead of
        // duplicating evidence. Acknowledge its explicit duplicate notice.
        if app.alerts.buttons["OK"].waitForExistence(timeout: 2) { app.alerts.buttons["OK"].tap() }
        XCTAssertTrue(app.buttons["Edit title, date, or working text"].waitForExistence(timeout: 10))
        let review = app.buttons["Review & edit"].firstMatch
        reveal(review, in: app); review.tap()
        XCTAssertTrue(app.navigationBars["Review claim"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["“Allergy: latex”"].exists)
        capture(app, "02-source-review")
        app.buttons["Cancel"].tap(); app.buttons["Done"].tap()

        selectTab("My Care", in: app); app.staticTexts["Medications"].tap()
        let medication = app.buttons.containing(.staticText, identifier: "Metoprolol succinate").firstMatch
        reveal(medication, in: app); medication.tap()
        XCTAssertTrue(app.staticTexts["This view reflects saved reports. It does not choose which clinical instruction is correct."].waitForExistence(timeout: 5))
        capture(app, "03-medication-reports")

        selectTab("Today", in: app)
        let companion = app.buttons["today-companion"]
        reveal(companion, in: app); companion.tap()
        XCTAssertTrue(app.navigationBars["My appointment"].waitForExistence(timeout: 5))
        capture(app, "04-appointment-companion")
        app.navigationBars.buttons.element(boundBy: 0).tap()
        selectTab("Visits", in: app)
        app.buttons["Prepare for your next visit"].tap(); app.buttons["Choose a visit packet"].tap()
        let preview = app.buttons["packet-preview"]
        XCTAssertTrue(preview.waitForExistence(timeout: 5)); preview.tap()
        XCTAssertTrue(app.staticTexts["packet-preview-text"].waitForExistence(timeout: 5))
        capture(app, "05-selected-packet")
        app.buttons["Done"].tap()

        selectTab("Today", in: app)
        let loops = app.staticTexts["Follow-through"].firstMatch
        reveal(loops, in: app); loops.tap()
        let helper = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH 'loop-help-'")).firstMatch
        reveal(helper, in: app); helper.tap()
        let waiting = app.buttons["assist-obstacle-waiting"]
        reveal(waiting, in: app); waiting.tap()
        XCTAssertTrue(app.textViews["assist-message"].waitForExistence(timeout: 5))
        capture(app, "06-follow-through-helper")
#endif
    }
    @MainActor private func capture(_ app: XCUIApplication, _ name: String) {
        let image = XCTAttachment(screenshot: app.screenshot()); image.name = name
        image.lifetime = .keepAlways; add(image)
    }
    @MainActor private func selectTab(_ name: String, in app: XCUIApplication) {
        // iPhone has a bottom tab bar; iPad uses UIKit's adaptive top tabs.
        let phoneTab = app.tabBars.buttons[name]
        if phoneTab.exists { phoneTab.tap(); return }
        let adaptiveTab = app.descendants(matching: .any).matching(NSPredicate(format: "label == %@ AND identifier IN %@", name, ["square.grid.2x2", "heart.text.clipboard", "calendar", "tray.full", "slider.horizontal.3"])).firstMatch
        XCTAssertTrue(adaptiveTab.waitForExistence(timeout: 10), "The actual adaptive tab must exist")
        adaptiveTab.tap()
    }
    @MainActor private func reveal(_ element: XCUIElement, in app: XCUIApplication) {
        for _ in 0..<12 {
            let frame = element.exists ? element.frame : .zero
            let navigation = app.navigationBars.allElementsBoundByIndex.last ?? app.navigationBars.firstMatch
            let top = navigation.exists ? navigation.frame.maxY : app.frame.minY + 60
            let tabs = app.tabBars.firstMatch
            let bottom = tabs.exists ? tabs.frame.minY : app.frame.maxY - 20
            if element.exists && element.isHittable && frame.minY > top && frame.maxY < bottom { return }
            // A normal iPad sheet sits over an existing tab/list hierarchy.
            // Scroll its visible form, rather than the background collection.
            let forms = (app.tables.allElementsBoundByIndex + app.collectionViews.allElementsBoundByIndex)
                .filter { $0.exists && $0.frame.height > 160 && $0.frame.intersects(app.frame) }
                .sorted { $0.frame.width * $0.frame.height < $1.frame.width * $1.frame.height }
            let scrolls = app.scrollViews.allElementsBoundByIndex.filter { $0.exists && $0.frame.height > 160 && $0.frame.intersects(app.frame) }
            let container = forms.first ?? scrolls.last ?? app.scrollViews.firstMatch
            let bounds = container.frame.intersection(app.frame.insetBy(dx: 12, dy: 110))
            XCTAssertFalse(bounds.isEmpty)
            let upward = frame.maxY >= bottom || frame.isEmpty
            let origin = app.coordinate(withNormalizedOffset: .zero)
            // Use the form edge: dragging through a UITextView scrolls the
            // editor itself instead of revealing the form's Save button.
            let x = bounds.minX + 10
            let start = origin.withOffset(CGVector(dx: x, dy: bounds.minY + bounds.height * (upward ? 0.7 : 0.3)))
            let end = origin.withOffset(CGVector(dx: x, dy: bounds.minY + bounds.height * (upward ? 0.3 : 0.7)))
            start.press(forDuration: 0.05, thenDragTo: end)
        }
        XCTAssertTrue(element.isHittable, "The actual release control must be reachable before capture")
    }
}
