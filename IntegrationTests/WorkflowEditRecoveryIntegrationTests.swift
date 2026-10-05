import XCTest
import CareCore
@testable import CareContinuity

@MainActor final class WorkflowEditRecoveryIntegrationTests: XCTestCase {
    func testDeletedFollowThroughCannotClaimItsStaleEditWasSaved() throws {
        let store = try fixture()
        let loop = try XCTUnwrap(store.state.loops.first)
        for sourceID in Set(loop.claimIDs.compactMap { id in store.state.claims.first { $0.id == id }?.sourceID }) {
            XCTAssertTrue(store.deleteSource(sourceID))
        }
        XCTAssertNil(store.state.loops.first { $0.id == loop.id })
        let committed = store.state
        XCTAssertFalse(store.setLoop(loop, status: .completed, note: "Fictional stale draft", due: nil, precision: .unknown, dateEdited: false))
        XCTAssertEqual(store.state, committed)
        XCTAssertTrue(store.error?.contains("not saved") == true)
    }
    func testLaterFollowThroughEditCannotBeOverwrittenByOpeningSnapshot() throws {
        let store = try fixture()
        let loop = try XCTUnwrap(store.state.loops.first)
        XCTAssertTrue(store.setLoop(loop, status: nil, note: "Saved newer progress", due: nil, precision: .unknown, dateEdited: false))
        let committed = store.state
        XCTAssertFalse(store.setLoop(loop, status: .completed, note: "Older pending edit", due: nil, precision: .unknown, dateEdited: false))
        XCTAssertEqual(store.state, committed)
        let current = try XCTUnwrap(store.state.loops.first { $0.id == loop.id })
        XCTAssertTrue(store.setLoop(current, status: .completed, note: "Confirmed personal completion", due: nil, precision: .unknown, dateEdited: false))
        XCTAssertTrue(store.state.loops.first { $0.id == loop.id }?.userCompleted == true)
    }
    func testStaleAndRemovedDiscrepancyEditsPreserveCurrentEvidence() throws {
        let store = try fixture()
        let conflict = try XCTUnwrap(store.state.conflicts.first)
        XCTAssertTrue(store.resolve(conflict, status: .clarified, note: "Fictional clarification"))
        let committed = store.state
        XCTAssertFalse(store.resolve(conflict, status: .dismissed, note: "Older pending edit"))
        XCTAssertEqual(store.state, committed)
        let current = try XCTUnwrap(store.state.conflicts.first { $0.id == conflict.id })
        for sourceID in Set(current.claimIDs.compactMap { id in store.state.claims.first { $0.id == id }?.sourceID }) {
            XCTAssertTrue(store.deleteSource(sourceID))
        }
        let removed = store.state
        XCTAssertFalse(store.resolve(current, status: .unresolved, note: "Stale reopen"))
        XCTAssertEqual(store.state, removed)
    }
    private func fixture() throws -> AppStore {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("CareInOneWorkflowEdit-" + UUID().uuidString)
        addTeardownBlock { try? FileManager.default.removeItem(at: root) }
        let repository = WorkflowEditRepository()
        try SyntheticDemo.load(into: &repository.state)
        return try AppStore(repository: repository, vault: EvidenceVault(root: root), systemServicesEnabled: false)
    }
}

@MainActor private final class WorkflowEditRepository: CareRepository {
    var state = CareState()
    func load() throws -> CareState { state }
    func save(_ value: CareState) throws { state = value }
}
