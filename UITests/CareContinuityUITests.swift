import XCTest

final class CareContinuityUITests: XCTestCase {
    @MainActor func testSyntheticDemoNavigationAndEvidence() throws {
        continueAfterFailure = false
        let app = XCUIApplication(); app.launchArguments = ["--uitesting", "--reset", "--demo"]; app.launch()
        XCTAssertTrue(app.tabBars.buttons["Today"].waitForExistence(timeout: 20))
        if app.alerts.buttons["OK"].exists { app.alerts.buttons["OK"].tap() }
        snapshot(app,"Today · synthetic care continuity")
        app.tabBars.buttons["My Care"].tap()
        XCTAssertTrue(app.staticTexts["Medications"].waitForExistence(timeout: 5)); app.staticTexts["Medications"].tap()
        XCTAssertTrue(app.staticTexts["Metoprolol succinate"].waitForExistence(timeout: 5)); app.staticTexts["Metoprolol succinate"].firstMatch.tap()
        XCTAssertTrue(app.staticTexts["Conflicting reports"].waitForExistence(timeout: 5))
        snapshot(app,"Medication · conflicting source evidence")
        app.tabBars.buttons["Sources"].tap()
        XCTAssertTrue(app.staticTexts["Synthetic · My medication update"].waitForExistence(timeout: 5))
        app.staticTexts["Synthetic · My medication update"].tap()
        XCTAssertTrue(app.buttons["Edit title, date, or working text"].waitForExistence(timeout: 5))
    }
    @MainActor func testCaptureReviewPersistsAcrossLaunch() throws {
        continueAfterFailure = false
        let app = XCUIApplication(); app.launchArguments = ["--uitesting", "--reset"]; app.launch()
        let start = app.buttons["Start with an empty care memory"]
        if !start.isHittable { app.swipeUp() }; XCTAssertTrue(start.waitForExistence(timeout: 10)); start.tap()
        XCTAssertTrue(app.buttons["global-add"].waitForExistence(timeout: 10)); app.buttons["global-add"].tap()
        let title = app.textFields["capture-title"]; XCTAssertTrue(title.waitForExistence(timeout: 5)); title.tap(); title.typeText("My quick recap")
        let text = app.textViews["capture-text"]; app.swipeUp(); text.tap(); text.typeText("Allergy: penicillin")
        app.swipeUp(); let save = app.buttons["save-evidence"]; XCTAssertTrue(save.waitForExistence(timeout: 5)); save.tap()
        let review = app.buttons["Review & edit"].firstMatch
        for _ in 0..<5 where !review.isHittable { app.swipeUp() }
        XCTAssertTrue(review.waitForExistence(timeout: 10)); review.tap()
        let confirmed = app.switches["This accurately reflects what was reported"]
        for _ in 0..<12 where !confirmed.isHittable { app.swipeUp() }
        XCTAssertTrue(confirmed.exists)
        // SwiftUI exposes the whole row as the switch. Target the actual native control.
        confirmed.coordinate(withNormalizedOffset: CGVector(dx:0.93,dy:0.5)).tap()
        let accept = app.buttons["accept-claim"]
        XCTAssertTrue(accept.isEnabled); snapshot(app,"Review · explicit patient confirmation"); accept.tap()
        XCTAssertTrue(accept.waitForNonExistence(timeout:5))
        app.terminate(); app.launchArguments = ["--uitesting"]; app.launch()
        XCTAssertTrue(app.tabBars.buttons["My Care"].waitForExistence(timeout: 10)); app.tabBars.buttons["My Care"].tap(); app.staticTexts["Allergies"].tap()
        XCTAssertTrue(app.staticTexts["penicillin"].waitForExistence(timeout: 5))
    }
    @MainActor private func snapshot(_ app:XCUIApplication,_ name:String) {
        let attachment=XCTAttachment(screenshot:app.screenshot()); attachment.name=name; attachment.lifetime = .keepAlways; add(attachment)
    }
    @MainActor func testDiscrepancyClarificationAndReopening() throws {
        continueAfterFailure=false
        let app=XCUIApplication(); app.launchArguments=["--uitesting","--reset","--demo"]; app.launch()
        XCTAssertTrue(app.tabBars.buttons["Today"].waitForExistence(timeout:20))
        if app.alerts.buttons["OK"].exists { app.alerts.buttons["OK"].tap() }
        app.staticTexts["To clarify"].tap()
        let row=app.staticTexts["Metoprolol succinate: dose differs"].firstMatch
        XCTAssertTrue(row.waitForExistence(timeout:5)); row.tap()
        XCTAssertTrue(app.navigationBars["Compare sources"].waitForExistence(timeout:5))
        snapshot(app,"Discrepancy · both reports preserved")
        let note=app.textFields["Your resolution note"]
        for _ in 0..<8 where !note.isHittable { app.swipeUp() }
        XCTAssertTrue(note.exists); note.tap(); note.typeText("Synthetic clarification: bring both records to the care team.")
        app.swipeUp(); let clarify=app.buttons["Mark clarified"]
        XCTAssertTrue(clarify.isEnabled); clarify.tap()
        XCTAssertTrue(app.navigationBars["Compare sources"].waitForNonExistence(timeout:5))
        let all=app.switches["Include clarified & dismissed"]
        all.coordinate(withNormalizedOffset:CGVector(dx:0.93,dy:0.5)).tap()
        let clarified=app.staticTexts["Clarified"].firstMatch
        XCTAssertTrue(clarified.waitForExistence(timeout:5)); clarified.tap()
        let reopen=app.buttons["Reopen discrepancy"]
        for _ in 0..<8 where !reopen.isHittable { app.swipeUp() }
        XCTAssertTrue(reopen.exists); reopen.tap()
        XCTAssertTrue(app.navigationBars["Compare sources"].waitForNonExistence(timeout:5))
        XCTAssertEqual(app.staticTexts.matching(identifier:"Unresolved").count,2)
    }
}
