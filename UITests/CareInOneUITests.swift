import XCTest

final class CareInOneUITests: XCTestCase {
    @MainActor func testCareConnectionsAtAccessibilityTextSize() throws {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launchArguments = ["--uitesting", "--reset", "--demo", "-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityXXXL"]
        app.launch()
        XCTAssertTrue(app.tabBars.buttons["My Care"].waitForExistence(timeout: 20))
        if app.alerts.buttons["OK"].exists { app.alerts.buttons["OK"].tap() }
        app.tabBars.buttons["My Care"].tap()
        let connections = app.buttons["care-connections"]
        for _ in 0..<8 where !connections.isHittable { scrollContent(app, up: true) }; connections.tap()
        snapshot(app, "CareInOne · care connections accessibility text")
        let timeline = app.buttons["intelligence-timeline"]
        for _ in 0..<8 where !timeline.isHittable { scrollContent(app, up: true) }; timeline.tap()
        XCTAssertTrue(app.navigationBars["Two-date timeline"].waitForExistence(timeout: 5))
        app.swipeUp(); snapshot(app, "CareInOne · timeline accessibility text")
    }
    @MainActor func testEvidenceGraphTimelineAndCombinedOmissionAreReachable() throws {
        continueAfterFailure = false
        let app = XCUIApplication(); app.launchArguments = ["--uitesting", "--reset", "--demo"]; app.launch()
        XCTAssertTrue(app.tabBars.buttons["My Care"].waitForExistence(timeout: 20))
        if app.alerts.buttons["OK"].exists { app.alerts.buttons["OK"].tap() }
        app.tabBars.buttons["My Care"].tap(); app.buttons["care-connections"].tap()
        snapshot(app, "CareInOne · care connections")
        app.buttons["intelligence-map"].tap()
        let medication = app.buttons["map-entity-Metoprolol succinate"]
        for _ in 0..<8 where !medication.isHittable { app.swipeUp() }
        XCTAssertTrue(medication.waitForExistence(timeout: 5)); medication.tap()
        XCTAssertTrue(app.buttons["Where it comes from"].waitForExistence(timeout: 5))
        snapshot(app, "CareInOne · medication evidence trace")
        app.buttons["What it informs"].tap()
        XCTAssertTrue(app.staticTexts["Step 1 · Discrepancy"].firstMatch.waitForExistence(timeout: 5))
        app.navigationBars.buttons.element(boundBy: 0).tap(); app.navigationBars.buttons.element(boundBy: 0).tap()
        app.buttons["intelligence-timeline"].tap()
        XCTAssertTrue(app.navigationBars["Two-date timeline"].waitForExistence(timeout: 5))
        snapshot(app, "CareInOne · two-date evidence timeline")
        app.buttons["timeline-axis"].tap(); app.buttons["Added here"].tap()
        XCTAssertTrue(app.staticTexts["Added here · newest first"].waitForExistence(timeout: 5))
        app.navigationBars.buttons.element(boundBy: 0).tap()
        let omission = app.buttons["intelligence-omission"]
        for _ in 0..<10 where !omission.isHittable { scrollContent(app, up: true) }
        XCTAssertTrue(omission.waitForExistence(timeout: 5)); XCTAssertTrue(omission.isHittable); omission.tap()
        let first = app.switches.matching(NSPredicate(format: "identifier BEGINSWITH 'omission-source-'")).element(boundBy: 0)
        for _ in 0..<5 where !first.isHittable { app.swipeUp() }
        first.coordinate(withNormalizedOffset: CGVector(dx: 0.93, dy: 0.5)).tap()
        let second = app.switches.matching(NSPredicate(format: "identifier BEGINSWITH 'omission-source-'")).element(boundBy: 1)
        second.coordinate(withNormalizedOffset: CGVector(dx: 0.93, dy: 0.5)).tap()
        let preview = app.buttons["omission-preview"]
        for _ in 0..<6 where !preview.isHittable { app.swipeDown() }; preview.tap()
        let result = app.staticTexts["omission-result"]
        for _ in 0..<4 where !result.isHittable { app.swipeUp() }
        XCTAssertTrue(result.waitForExistence(timeout: 15)); XCTAssertEqual(result.label, "2 sources left out")
        snapshot(app, "CareInOne · combined evidence omission")
        app.tabBars.buttons["Sources"].tap()
        XCTAssertTrue(app.staticTexts["Synthetic · My medication update"].waitForExistence(timeout: 5))
    }

    @MainActor func testEmptyPatientHandoffPDFDraftRelaunchAndReplyReview() throws {
        continueAfterFailure = false
        let app = XCUIApplication(); app.launchArguments = ["--uitesting", "--reset"]; app.launch()
        let start = app.buttons["Start with an empty care memory"]
        for _ in 0..<5 where !start.isHittable { app.swipeUp() }; XCTAssertTrue(start.waitForExistence(timeout: 10)); start.tap()
        app.tabBars.buttons["Visits"].tap(); app.buttons["visits-handoffs"].tap(); app.buttons["handoff-new"].tap()
        let priority = app.textFields["packet-priority"]
        for _ in 0..<4 where !priority.isHittable { app.swipeUp() }; priority.tap(); priority.typeText("Which records should I bring?")
        app.buttons["Save to my visit questions"].tap()
        XCTAssertTrue(app.alerts.staticTexts["Question saved."].waitForExistence(timeout: 5), "Acknowledge the actual successful-save notice before continuing the packet")
        app.alerts.buttons["OK"].tap()
        let track = app.buttons["packet-track"]
        for _ in 0..<12 {
            if track.exists {
                let frame = track.frame
                if track.isHittable && frame.minY > app.navigationBars.firstMatch.frame.maxY + 4 && frame.maxY < app.tabBars.firstMatch.frame.minY { break }
            }
            scrollContent(app, up: false)
        }
        XCTAssertTrue(track.isHittable); XCTAssertTrue(track.isEnabled); track.tap()
        let title = app.textFields["handoff-title"]; XCTAssertTrue(title.waitForExistence(timeout: 5)); title.tap(); title.typeText("First care handoff")
        app.buttons["handoff-save"].tap()
        XCTAssertTrue(app.buttons["handoff-snapshot"].waitForExistence(timeout: 5)); app.buttons["handoff-snapshot"].tap()
        XCTAssertTrue(app.staticTexts["handoff-snapshot-text"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["handoff-snapshot-text"].label.contains("Which records should I bring?"))
        app.buttons["handoff-pdf"].tap(); XCTAssertTrue(app.buttons["Share handoff PDF"].waitForExistence(timeout: 10))
        snapshot(app, "CareInOne · exact selected handoff copy")
        app.buttons["Done"].tap(); app.buttons["handoff-shared"].tap()
        XCTAssertTrue(app.staticTexts["Shared by your report"].waitForExistence(timeout: 5))
        let reply = app.buttons["handoff-reply"]
        for _ in 0..<6 where !reply.isHittable { app.swipeUp() }; reply.tap()
        let text = app.textViews["handoff-reply-text"]; XCTAssertTrue(text.waitForExistence(timeout: 5)); text.tap(); text.typeText("Allergy: latex")
        app.buttons["handoff-reply-save-draft"].tap()
        app.terminate(); app.launchArguments = ["--uitesting"]; app.launch()
        XCTAssertTrue(app.tabBars.buttons["Visits"].waitForExistence(timeout: 15)); app.tabBars.buttons["Visits"].tap(); app.buttons["visits-handoffs"].tap()
        app.buttons["handoff-row-First care handoff"].tap()
        for _ in 0..<6 where !reply.isHittable { app.swipeUp() }; reply.tap()
        XCTAssertTrue(text.waitForExistence(timeout: 5)); XCTAssertEqual(text.value as? String, "Allergy: latex")
        let capture = app.buttons["handoff-reply-capture"]
        for _ in 0..<5 where !capture.isHittable { app.swipeUp() }; capture.tap()
        let review = app.buttons["Review & edit"].firstMatch
        for _ in 0..<8 where !review.isHittable { app.swipeUp() }; XCTAssertTrue(review.waitForExistence(timeout: 10)); review.tap()
        let confirm = app.switches["This accurately reflects what was reported"]
        for _ in 0..<12 where !confirm.isHittable { app.swipeUp() }; confirm.coordinate(withNormalizedOffset: CGVector(dx: 0.93, dy: 0.5)).tap()
        let accept = app.buttons["accept-claim"]
        for _ in 0..<4 where !accept.isHittable { app.swipeUp() }; accept.tap()
        XCTAssertTrue(accept.waitForNonExistence(timeout: 5))
        app.tabBars.buttons["My Care"].tap(); app.staticTexts["Allergies"].tap()
        XCTAssertTrue(app.staticTexts["latex"].waitForExistence(timeout: 5))
    }

    @MainActor func testFinishedHandoffFlagsNewReviewedEvidenceAndReopens() throws {
        continueAfterFailure = false
        let app = XCUIApplication(); app.launchArguments = ["--uitesting", "--reset", "--demo"]; app.launch()
        XCTAssertTrue(app.tabBars.buttons["Visits"].waitForExistence(timeout: 20))
        if app.alerts.buttons["OK"].exists { app.alerts.buttons["OK"].tap() }
        app.tabBars.buttons["Visits"].tap(); app.buttons["visits-handoffs"].tap(); app.buttons["handoff-new"].tap()
        app.buttons["packet-track"].tap()
        let title = app.textFields["handoff-title"]; XCTAssertTrue(title.waitForExistence(timeout: 5)); title.tap(); title.typeText("Synthetic outgoing copy")
        app.buttons["handoff-save"].tap()
        let finish = app.buttons["handoff-finish"]
        for _ in 0..<7 where !finish.isHittable { app.swipeUp() }; finish.tap(); app.buttons["Finish handoff"].tap()
        let reply = app.buttons["handoff-reply"]
        for _ in 0..<6 where !reply.isHittable { app.swipeUp() }; reply.tap()
        let text = app.textViews["handoff-reply-text"]; XCTAssertTrue(text.waitForExistence(timeout: 5)); text.tap(); text.typeText("Allergy: penicillin")
        let capture = app.buttons["handoff-reply-capture"]
        for _ in 0..<5 where !capture.isHittable { app.swipeUp() }; capture.tap()
        let review = app.buttons["Review & edit"].firstMatch
        for _ in 0..<8 where !review.isHittable { app.swipeUp() }; XCTAssertTrue(review.waitForExistence(timeout: 10)); review.tap()
        let confirm = app.switches["This accurately reflects what was reported"]
        for _ in 0..<12 where !confirm.isHittable { app.swipeUp() }; confirm.coordinate(withNormalizedOffset: CGVector(dx: 0.93, dy: 0.5)).tap()
        let accept = app.buttons["accept-claim"]
        for _ in 0..<4 where !accept.isHittable { app.swipeUp() }; accept.tap()
        XCTAssertTrue(accept.waitForNonExistence(timeout: 5)); app.navigationBars.buttons.element(boundBy: 0).tap()
        let drift = app.staticTexts["handoff-finish-drift"]
        for _ in 0..<12 where !drift.isHittable { app.swipeUp() }
        XCTAssertTrue(drift.waitForExistence(timeout: 5)); snapshot(app, "CareInOne · new information after handoff finish")
        let reopen = app.buttons["handoff-reopen"]
        for _ in 0..<5 where !reopen.isHittable { app.swipeUp() }; reopen.tap()
        XCTAssertTrue(reopen.waitForNonExistence(timeout: 5))
    }
    @MainActor func testEmptyPatientVisitDebriefReviewImpactAndCheckpoint() throws {
        continueAfterFailure = false
        let app = XCUIApplication(); app.launchArguments = ["--uitesting", "--reset"]; app.launch()
        let start = app.buttons["Start with an empty care memory"]
        for _ in 0..<4 where !start.isHittable { app.swipeUp() }
        XCTAssertTrue(start.waitForExistence(timeout: 10)); start.tap()
        XCTAssertTrue(app.tabBars.buttons["Visits"].waitForExistence(timeout: 10)); app.tabBars.buttons["Visits"].tap()
        app.buttons["visits-workspaces"].tap(); app.buttons["workspace-new"].tap()
        let title = app.textFields["workspace-title"]
        XCTAssertTrue(title.waitForExistence(timeout: 5)); title.tap(); title.typeText("Synthetic first visit")
        app.buttons["workspace-save"].tap()
        let reference = app.buttons["workspace-checkpoint"]
        for _ in 0..<6 where !reference.isHittable { app.swipeUp() }
        XCTAssertTrue(reference.waitForExistence(timeout: 5)); reference.tap()
        app.buttons["checkpoint-save"].tap()
        XCTAssertTrue(app.buttons["workspace-compare"].waitForExistence(timeout: 5))
        let debrief = app.buttons["workspace-debrief"]
        for _ in 0..<6 where !debrief.isHittable { app.swipeUp() }; debrief.tap()
        let heard = app.textViews["debrief-heard"]
        XCTAssertTrue(heard.waitForExistence(timeout: 5)); heard.tap(); heard.typeText("Allergy: latex")
        let questions = app.textViews["debrief-questions"]
        for _ in 0..<6 where !questions.isHittable { app.swipeUp() }; questions.tap(); questions.typeText("Which records should I bring?")
        let save = app.buttons["debrief-save-evidence"]
        for _ in 0..<8 where !save.isHittable { app.swipeUp() }; save.tap()
        let review = app.buttons["Review & edit"].firstMatch
        for _ in 0..<8 where !review.isHittable { app.swipeUp() }
        XCTAssertTrue(review.waitForExistence(timeout: 10)); review.tap()
        let confirmed = app.switches["This accurately reflects what was reported"]
        for _ in 0..<12 where !confirmed.isHittable { app.swipeUp() }
        confirmed.coordinate(withNormalizedOffset: CGVector(dx: 0.93, dy: 0.5)).tap()
        let impact = app.buttons["review-impact"]
        for _ in 0..<4 where !impact.isHittable { app.swipeUp() }; impact.tap()
        XCTAssertTrue(app.navigationBars["Impact preview"].waitForExistence(timeout: 5))
        snapshot(app, "CareInOne · local review impact")
        app.buttons["Done"].tap()
        let accept = app.buttons["accept-claim"]
        for _ in 0..<4 where !accept.isHittable { app.swipeUp() }; accept.tap()
        XCTAssertTrue(accept.waitForNonExistence(timeout: 5))
        app.navigationBars.buttons.element(boundBy: 0).tap()
        let compare = app.buttons["workspace-compare"]
        for _ in 0..<6 where !compare.isHittable { app.swipeDown() }
        XCTAssertTrue(compare.waitForExistence(timeout: 5)); compare.tap()
        for _ in 0..<5 where !app.staticTexts["latex"].firstMatch.exists { app.swipeUp() }
        snapshot(app, "CareInOne · checkpoint comparison result")
        XCTAssertTrue(app.staticTexts["latex"].firstMatch.waitForExistence(timeout: 5))
        XCTAssertFalse(app.staticTexts["comparison-empty"].exists)
        snapshot(app, "CareInOne · checkpoint after reviewed recollection")
        let export = app.buttons["checkpoint-export"]
        for _ in 0..<5 where !export.isHittable { app.swipeDown() }; export.tap()
        XCTAssertTrue(app.buttons["Share comparison text"].waitForExistence(timeout: 5))
    }

    @MainActor func testVisitDraftPersistsAcrossRelaunchAndDeletionHasImpactPreview() throws {
        continueAfterFailure = false
        let app = XCUIApplication(); app.launchArguments = ["--uitesting", "--reset", "--demo"]; app.launch()
        XCTAssertTrue(app.tabBars.buttons["Visits"].waitForExistence(timeout: 20))
        if app.alerts.buttons["OK"].exists { app.alerts.buttons["OK"].tap() }
        app.tabBars.buttons["Visits"].tap(); app.buttons["visits-workspaces"].tap(); app.buttons["workspace-new"].tap()
        let title = app.textFields["workspace-title"]; XCTAssertTrue(title.waitForExistence(timeout: 5)); title.tap(); title.typeText("Synthetic draft visit")
        app.buttons["workspace-save"].tap()
        XCTAssertTrue(app.navigationBars["Visit workspace"].waitForExistence(timeout: 5))
        let debrief = app.buttons["workspace-debrief"]
        for _ in 0..<12 where !debrief.isHittable { scrollContent(app, up: true) }
        XCTAssertTrue(debrief.waitForExistence(timeout: 5)); XCTAssertTrue(debrief.isHittable); debrief.tap()
        let heard = app.textViews["debrief-heard"]
        XCTAssertTrue(heard.waitForExistence(timeout: 5)); heard.tap(); heard.typeText("I want to remember our conversation.")
        let editingDone = app.buttons["debrief-text-done"]
        XCTAssertTrue(editingDone.waitForExistence(timeout: 5)); editingDone.tap()
        XCTAssertTrue(app.keyboards.firstMatch.waitForNonExistence(timeout: 5))
        let draft = app.buttons["debrief-save-draft"]
        for _ in 0..<12 where !draft.isHittable { scrollContent(app, up: true) }
        XCTAssertTrue(draft.waitForExistence(timeout: 5)); XCTAssertTrue(draft.isHittable); draft.tap()
        app.terminate(); app.launchArguments = ["--uitesting"]; app.launch()
        XCTAssertTrue(app.tabBars.buttons["Visits"].waitForExistence(timeout: 10)); app.tabBars.buttons["Visits"].tap(); app.buttons["visits-workspaces"].tap()
        XCTAssertFalse(app.staticTexts["Synthetic draft visit"].exists, "Practice visit drafts must not appear in the personal patient history after relaunch")
        reopenIsolatedDemo(app)
        app.tabBars.buttons["Visits"].tap(); app.buttons["visits-workspaces"].tap()
        app.staticTexts["Synthetic draft visit"].tap()
        XCTAssertTrue(app.navigationBars["Visit workspace"].waitForExistence(timeout: 5))
        for _ in 0..<12 where !debrief.isHittable { scrollContent(app, up: true) }
        XCTAssertTrue(debrief.waitForExistence(timeout: 5)); XCTAssertTrue(debrief.isHittable); debrief.tap()
        XCTAssertTrue(heard.waitForExistence(timeout: 5))
        XCTAssertTrue((heard.value as? String)?.contains("I want to remember our conversation.") == true)
        app.buttons["Cancel"].tap()
        app.tabBars.buttons["Sources"].tap(); app.staticTexts["Synthetic · My medication update"].tap()
        let delete = app.buttons["Delete source and its claims"]
        for _ in 0..<18 where !delete.isHittable { app.swipeUp() }
        XCTAssertTrue(delete.exists); delete.tap()
        XCTAssertTrue(app.navigationBars["Deletion preview"].waitForExistence(timeout: 5))
        snapshot(app, "CareInOne · source deletion impact")
        app.buttons["Done"].tap()
        XCTAssertTrue(app.navigationBars["Source evidence"].waitForExistence(timeout: 5))
    }
    @MainActor func testVisitPacketSelectionPreviewAndPDF() throws {
        continueAfterFailure = false
        let app = XCUIApplication(); app.launchArguments = ["--uitesting", "--reset", "--demo"]; app.launch()
        XCTAssertTrue(app.tabBars.buttons["Visits"].waitForExistence(timeout: 20))
        if app.alerts.buttons["OK"].exists { app.alerts.buttons["OK"].tap() }
        app.tabBars.buttons["Visits"].tap()
        app.buttons["Prepare for your next visit"].tap()
        app.buttons["Choose a visit packet"].tap()
        let preview = app.buttons["packet-preview"]
        XCTAssertTrue(preview.waitForExistence(timeout: 5)); preview.tap()
        XCTAssertTrue(app.staticTexts["packet-preview-text"].waitForExistence(timeout: 5))
        snapshot(app, "CareInOne · selected visit packet")
        app.buttons["packet-pdf"].tap()
        XCTAssertTrue(app.buttons["Share selected PDF"].waitForExistence(timeout: 10))
        app.buttons["Done"].tap()
        let clear = app.buttons["packet-clear"]
        for _ in 0..<6 where !clear.isHittable { app.swipeUp() }
        clear.tap()
        for _ in 0..<6 where !preview.isHittable { app.swipeDown() }
        XCTAssertFalse(preview.isEnabled)
    }

    @MainActor func testOutgoingMessageEditingInvalidatesPreviousPDF() throws {
        continueAfterFailure = false
        let app = XCUIApplication(); app.launchArguments = ["--uitesting", "--reset", "--demo"]; app.launch()
        XCTAssertTrue(app.tabBars.buttons["Visits"].waitForExistence(timeout: 20))
        if app.alerts.buttons["OK"].exists { app.alerts.buttons["OK"].tap() }
        app.tabBars.buttons["Visits"].tap()
        app.buttons["Prepare for your next visit"].tap()
        app.buttons["Choose a visit packet"].tap()
        let format = app.switches["Format as a message to my care team"]
        let packetBar = app.navigationBars["Visit packet"]
        for _ in 0..<10 {
            let frame = format.frame
            if format.isHittable && frame.minY > packetBar.frame.maxY + 4 && frame.maxY < app.tabBars.firstMatch.frame.minY { break }
            scrollContent(app, up: frame.maxY >= app.tabBars.firstMatch.frame.minY)
        }
        XCTAssertTrue(format.isHittable)
        XCTAssertGreaterThan(format.frame.minY, packetBar.frame.maxY + 4)
        XCTAssertLessThan(format.frame.maxY, app.tabBars.firstMatch.frame.minY)
        // List deceleration can move a row between accessibility snapshots.
        // Wait for consecutive identical native rectangles before measuring
        // the knob, instead of tapping an earlier scrolling snapshot.
        var previousFrame: CGRect?
        let stableFrame = XCTNSPredicateExpectation(predicate: NSPredicate { element, _ in
            guard let element = element as? XCUIElement, element.exists, element.isHittable else { return false }
            let frame = element.frame
            defer { previousFrame = frame }
            return previousFrame == frame
        }, object: format)
        XCTAssertEqual(XCTWaiter.wait(for: [stableFrame], timeout: 20), .completed, "Allow two complete native accessibility snapshots to confirm the row has stopped moving")
        if format.value as? String == "0" {
            // SwiftUI exposes the entire labelled row as the Switch element.
            // Its activation point can land on the label; target the visible
            // native knob using one measured app-space rectangle instead.
            let frame = format.frame, bounds = app.frame
            let center = app.coordinate(withNormalizedOffset: .zero).withOffset(CGVector(dx: frame.maxX - 40 - bounds.minX, dy: frame.midY - bounds.minY))
            center.tap()
        }
        let switchOn = XCTNSPredicateExpectation(predicate: NSPredicate(format: "value == '1'"), object: format)
        XCTAssertEqual(XCTWaiter.wait(for: [switchOn], timeout: 5), .completed, "Wait for the native switch to finish changing state")
        XCTAssertEqual(format.value as? String, "1", "The message-format switch must be on before opening the editable snapshot")
        let preview = app.buttons["packet-preview"]
        for _ in 0..<10 {
            if preview.exists {
                let frame = preview.frame
                if preview.isHittable && frame.minY > packetBar.frame.maxY + 4 && frame.maxY < app.tabBars.firstMatch.frame.minY { break }
            }
            scrollContent(app, up: false)
        }
        XCTAssertTrue(app.navigationBars["Visit packet"].exists)
        XCTAssertTrue(app.tabBars.buttons["Visits"].isSelected)
        XCTAssertTrue(preview.isHittable)
        XCTAssertGreaterThan(preview.frame.minY, packetBar.frame.maxY + 4, "The actual preview button must be below the navigation bar, not the fictional-demo banner")
        preview.tap()
        let editor = app.textViews["packet-message-text"]
        XCTAssertTrue(editor.waitForExistence(timeout: 5))
        app.buttons["packet-pdf"].tap()
        XCTAssertTrue(app.buttons["Share selected PDF"].waitForExistence(timeout: 10))
        editor.tap(); editor.typeText("Please discuss my priorities. ")
        XCTAssertTrue(app.buttons["Share selected PDF"].waitForNonExistence(timeout: 5))
        XCTAssertTrue((editor.value as? String)?.contains("Please discuss my priorities.") == true)
        app.buttons["Done"].tap()
        preview.tap()
        XCTAssertTrue(editor.waitForExistence(timeout: 5))
        XCTAssertFalse((editor.value as? String)?.contains("Please discuss my priorities.") == true, "Editing an outgoing copy must not alter saved care or the next generated snapshot")
    }

    @MainActor func testPersonalNoteCreatePersistAndDelete() throws {
        continueAfterFailure = false
        let app = XCUIApplication(); app.launchArguments = ["--uitesting", "--reset", "--demo"]; app.launch()
        XCTAssertTrue(app.tabBars.buttons["My Care"].waitForExistence(timeout: 20))
        if app.alerts.buttons["OK"].exists { app.alerts.buttons["OK"].tap() }
        app.tabBars.buttons["My Care"].tap()
        let notes = app.buttons["Personal notes"]
        for _ in 0..<10 where !notes.isHittable { app.swipeUp() }
        XCTAssertTrue(notes.waitForExistence(timeout: 5)); notes.tap()
        app.buttons["Write a personal note"].tap()
        let text = app.textViews["personal-note-text"]
        XCTAssertTrue(text.waitForExistence(timeout: 5)); text.tap(); text.typeText("Bring my written questions")
        app.buttons["Save changes"].tap()
        XCTAssertTrue(app.staticTexts["Bring my written questions"].waitForExistence(timeout: 5))
        app.terminate(); app.launchArguments = ["--uitesting"]; app.launch()
        XCTAssertTrue(app.tabBars.buttons["My Care"].waitForExistence(timeout: 10)); app.tabBars.buttons["My Care"].tap()
        for _ in 0..<10 where !notes.isHittable { app.swipeUp() }
        notes.tap()
        XCTAssertFalse(app.staticTexts["Bring my written questions"].exists, "A fictional practice note must stay outside the personal patient history")
        reopenIsolatedDemo(app)
        app.tabBars.buttons["My Care"].tap()
        for _ in 0..<10 where !notes.isHittable { app.swipeUp() }
        notes.tap()
        XCTAssertTrue(app.staticTexts["Bring my written questions"].waitForExistence(timeout: 5))
        app.buttons["Edit note"].firstMatch.tap()
        let delete = app.buttons["Delete note"]
        for _ in 0..<10 where !delete.isHittable { scrollContent(app, up: true) }
        XCTAssertTrue(delete.waitForExistence(timeout: 5)); XCTAssertTrue(delete.isHittable); delete.tap()
        app.buttons["Delete note permanently"].tap()
        XCTAssertTrue(app.staticTexts["Bring my written questions"].waitForNonExistence(timeout: 5))
    }
    @MainActor private func scrollContent(_ app: XCUIApplication, up: Bool) {
        let bounds = app.frame
        let surfaces = app.tables.allElementsBoundByIndex + app.collectionViews.allElementsBoundByIndex + app.scrollViews.allElementsBoundByIndex
        let frames = surfaces.compactMap { surface -> CGRect? in
            guard surface.exists, surface.isHittable else { return nil }
            let frame = surface.frame
            guard frame.width > 0, frame.height > 100, frame.minX >= bounds.minX - 1, frame.maxX <= bounds.maxX + 1 else { return nil }
            return frame
        }
        let frame = frames.max { $0.width * $0.height < $1.width * $1.height } ?? bounds
        let navBottom = app.navigationBars.allElementsBoundByIndex.filter(\.exists).map { $0.frame.maxY }.max() ?? frame.minY
        let tabTop = app.tabBars.allElementsBoundByIndex.filter(\.exists).map { $0.frame.minY }.min() ?? frame.maxY
        let keyboardTop = app.keyboards.firstMatch.exists ? app.keyboards.firstMatch.frame.minY : frame.maxY
        let top = max(frame.minY, navBottom) + 16
        let bottom = min(frame.maxY, min(tabTop, keyboardTop)) - 16
        guard bottom - top > 50 else { XCTFail("No visible packet content region is available"); return }
        let origin = app.coordinate(withNormalizedOffset: .zero)
        let high = top + (bottom - top) * 0.2 - bounds.minY
        let low = top + (bottom - top) * 0.8 - bounds.minY
        let start = origin.withOffset(CGVector(dx: frame.midX - bounds.minX, dy: up ? low : high))
        let end = origin.withOffset(CGVector(dx: frame.midX - bounds.minX, dy: up ? high : low))
        start.press(forDuration: 0.05, thenDragTo: end)
    }
    @MainActor func testPracticeImportThroughCaptureAndReview() throws {
        continueAfterFailure = false
        let app = XCUIApplication(); app.launchArguments = ["--uitesting", "--reset", "--demo"]; app.launch()
        XCTAssertTrue(app.tabBars.buttons["Today"].waitForExistence(timeout: 20))
        if app.alerts.buttons["OK"].exists { app.alerts.buttons["OK"].tap() }
        app.tabBars.buttons["Settings"].tap()
        let practice = app.buttons["practice-imports"]
        for _ in 0..<10 where !practice.isHittable { app.swipeUp() }
        XCTAssertTrue(practice.waitForExistence(timeout: 5)); practice.tap()
        let sample = app.buttons["practice-import-txt"]
        XCTAssertTrue(sample.waitForExistence(timeout: 5)); sample.tap()
        let save = app.buttons["save-evidence"]
        for _ in 0..<10 where !save.isHittable { app.swipeUp() }
        XCTAssertTrue(save.waitForExistence(timeout: 10)); XCTAssertTrue(save.isEnabled); save.tap()
        XCTAssertTrue(app.staticTexts["Synthetic demo"].waitForExistence(timeout: 10))
        let review = app.buttons["Review & edit"].firstMatch
        for _ in 0..<10 where !review.isHittable { app.swipeUp() }
        XCTAssertTrue(review.waitForExistence(timeout: 10))
    }
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
    @MainActor private func reopenIsolatedDemo(_ app: XCUIApplication) {
        let settings = app.tabBars.buttons["Settings"]
        XCTAssertTrue(settings.waitForExistence(timeout: 10)); settings.tap()
        let explore = app.buttons["open-demo"]
        for _ in 0..<12 where !explore.isHittable { app.swipeUp() }
        XCTAssertTrue(explore.waitForExistence(timeout: 5)); explore.tap()
        XCTAssertTrue(app.buttons["Return to my care"].waitForExistence(timeout: 10), "The fictional workspace must be explicitly reopened before checking its persisted practice records")
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
