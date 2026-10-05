import XCTest
import CareCore
@testable import CareContinuity

@MainActor final class WorkspaceIsolationIntegrationTests: XCTestCase {
    func testFictionalDemoCannotMergeWithPersonalCareAndSurvivesRelaunch() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let cleanupRoot1 = root; addTeardownBlock { try? FileManager.default.removeItem(at: cleanupRoot1) }
        let personal = try AppStore(repository: SwiftDataRepository(root: root), vault: EvidenceVault(root: root), systemServicesEnabled: false)
        let id = try personal.capture(title: "Personal fictional test record", kind: .typed, text: "Allergy: latex", analyze: false)
        XCTAssertTrue(personal.accept(try LocalExtractor.proposals(XCTUnwrap(personal.source(id)))))
        let original = personal.state
        let demoRoot = root.appendingPathComponent("FictionalDemo")
        let demo = try AppStore(repository: SwiftDataRepository(root: demoRoot), vault: EvidenceVault(root: demoRoot), isDemoWorkspace: true, systemServicesEnabled: false)
        demo.resetDemoWorkspace()
        XCTAssertTrue(demo.state.profile.demoLoaded)
        XCTAssertNil(demo.source(id))
        let practice = try demo.capture(title: "Practice note", kind: .typed, text: "Allergy: fictional pollen", analyze: false)
        XCTAssertTrue(demo.source(practice)?.synthetic == true)
        XCTAssertEqual(personal.state, original)
        let reopened = try AppStore(repository: SwiftDataRepository(root: demoRoot), vault: EvidenceVault(root: demoRoot), isDemoWorkspace: true, systemServicesEnabled: false)
        XCTAssertNotNil(reopened.source(practice))
        demo.resetDemoWorkspace()
        XCTAssertNil(demo.source(practice))
        let reopenedPersonal = try AppStore(repository: SwiftDataRepository(root: root), vault: EvidenceVault(root: root), systemServicesEnabled: false)
        XCTAssertEqual(reopenedPersonal.state, original)
        XCTAssertEqual(reopenedPersonal.state.entities.first?.label.lowercased(), "latex")
    }
    func testDemoRestoreRejectsPersonalBackupWithoutChangingEitherPatient() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let cleanupRoot2 = root; addTeardownBlock { try? FileManager.default.removeItem(at: cleanupRoot2) }
        let personal = try AppStore(repository: SwiftDataRepository(root: root), vault: EvidenceVault(root: root), systemServicesEnabled: false)
        _ = try personal.capture(title: "Personal", kind: .typed, text: "Private fictional patient note", analyze: false)
        let archive = try personal.archive(includeAudio: true)
        let demoRoot = root.appendingPathComponent("FictionalDemo")
        let demo = try AppStore(repository: SwiftDataRepository(root: demoRoot), vault: EvidenceVault(root: demoRoot), isDemoWorkspace: true, systemServicesEnabled: false)
        demo.resetDemoWorkspace()
        let before = demo.state
        XCTAssertThrowsError(try demo.restore(archive))
        XCTAssertEqual(demo.state, before)
        XCTAssertEqual(personal.state, archive.state)
    }
    func testPersonalRestoreReplacesHistoryInsteadOfMixingPatients() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let cleanupRoot3 = root; addTeardownBlock { try? FileManager.default.removeItem(at: cleanupRoot3) }
        let store = try AppStore(repository: SwiftDataRepository(root: root), vault: EvidenceVault(root: root), clearBackendOnErase: false, systemServicesEnabled: false)
        let first = try store.capture(title: "Fictional patient A", kind: .typed, text: "Patient A note", analyze: false)
        let patientA = try store.archive(includeAudio: false)
        store.eraseAll()
        let second = try store.capture(title: "Fictional patient B", kind: .typed, text: "Patient B note", analyze: false)
        try store.restore(patientA)
        XCTAssertNotNil(store.source(first))
        XCTAssertNil(store.source(second))
        XCTAssertFalse(store.state.profile.cloudConsent)
        XCTAssertFalse(store.state.profile.notifications)
    }
}
