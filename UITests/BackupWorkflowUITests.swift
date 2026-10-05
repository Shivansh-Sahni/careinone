import XCTest

final class BackupWorkflowUITests: XCTestCase {
    @MainActor func testBackupCreationAndAudioChangeInvalidateOldShare() throws {
        continueAfterFailure = false
        let app = XCUIApplication(); app.launchArguments = ["--uitesting", "--reset"]; app.launch()
        let start = app.buttons["Start with an empty care memory"]
        for _ in 0..<4 where !start.isHittable { app.swipeUp() }
        XCTAssertTrue(start.waitForExistence(timeout: 15)); start.tap()
        XCTAssertTrue(app.tabBars.buttons["Settings"].waitForExistence(timeout: 10)); app.tabBars.buttons["Settings"].tap()
        let backup = app.buttons["Encrypted backup & restore"]
        for _ in 0..<14 where !backup.isHittable { app.swipeUp() }
        XCTAssertTrue(backup.waitForExistence(timeout: 5)); backup.tap()
        let passphrase = app.secureTextFields["backup-passphrase"]
        XCTAssertTrue(passphrase.waitForExistence(timeout: 5)); passphrase.tap(); passphrase.typeText("fictional patient backup phrase")
        let confirmation = app.secureTextFields["backup-confirmation"]
        for _ in 0..<4 where !confirmation.isHittable { app.swipeUp() }
        confirmation.tap(); confirmation.typeText("fictional patient backup phrase")
        let done = app.buttons["backup-keyboard-done"]
        XCTAssertTrue(done.waitForExistence(timeout: 5)); done.tap(); XCTAssertEqual(app.keyboards.count, 0)
        let create = app.buttons["backup-create"]
        for _ in 0..<5 where !create.isHittable { app.swipeUp() }
        XCTAssertTrue(create.isEnabled); create.tap()
        let share = app.buttons["backup-share"]
        XCTAssertTrue(share.waitForExistence(timeout: 15))
        let readyMessage = app.descendants(matching: .any).matching(identifier: "backup-message").firstMatch
        for _ in 0..<6 where !readyMessage.exists { app.swipeUp() }
        XCTAssertTrue(readyMessage.waitForExistence(timeout: 5))
        XCTAssertTrue(readyMessage.label.contains("Encrypted backup ready"))
        let attachment = XCTAttachment(screenshot: app.screenshot()); attachment.name = "Encrypted backup created locally"; attachment.lifetime = .keepAlways; add(attachment)
        let audio = app.switches["backup-include-audio"]
        for _ in 0..<5 where !audio.isHittable { app.swipeDown() }
        XCTAssertTrue(audio.waitForExistence(timeout: 5))
        let oldValue = audio.value as? String
        audio.coordinate(withNormalizedOffset: CGVector(dx: 0.93, dy: 0.5)).tap()
        XCTAssertNotEqual(audio.value as? String, oldValue)
        XCTAssertTrue(share.waitForNonExistence(timeout: 5))
        let message = app.descendants(matching: .any).matching(identifier: "backup-message").firstMatch
        for _ in 0..<6 where !message.isHittable { app.swipeUp() }
        XCTAssertTrue(message.label.contains("Create a new backup"))
        app.terminate()
    }
}
