import XCTest
import CareCore
@testable import CareContinuity

@MainActor final class EntityAliasIntegrationTests: XCTestCase {
    func testAliasAdditionAndRemovalPersistWithoutChangingReviewedAssociations() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("CareInOneAliasPersistence-" + UUID().uuidString)
        addTeardownBlock { try? FileManager.default.removeItem(at: root) }
        let store = try AppStore(repository: SwiftDataRepository(root: root), vault: EvidenceVault(root: root), systemServicesEnabled: false)
        let id = try savedItem(in: store); let claims = store.state.claims; let sources = store.state.sources
        XCTAssertTrue(store.mutate { try EntityAliasPolicy.add("  Another\nrecognized name  ", to: id, in: &$0) })
        let reopened = try AppStore(repository: SwiftDataRepository(root: root), vault: EvidenceVault(root: root), systemServicesEnabled: false)
        XCTAssertEqual(reopened.state.entity(id)?.aliases, ["Another recognized name"])
        XCTAssertEqual(reopened.state.claims, claims); XCTAssertEqual(reopened.state.sources, sources)
        XCTAssertTrue(reopened.mutate { try EntityAliasPolicy.remove("ANOTHER recognized name", from: id, in: &$0) })
        let restored = try AppStore(repository: SwiftDataRepository(root: root), vault: EvidenceVault(root: root), systemServicesEnabled: false)
        XCTAssertEqual(restored.state.entity(id)?.aliases, [])
        XCTAssertEqual(restored.state.claims, claims); XCTAssertEqual(restored.state.claims(for: id).count, 1)
    }

    func testStorageFailuresAndDeletedItemsRetainPreviousCommittedState() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("CareInOneAliasFailure-" + UUID().uuidString)
        addTeardownBlock { try? FileManager.default.removeItem(at: root) }
        let repository = AliasRepository()
        let store = try AppStore(repository: repository, vault: EvidenceVault(root: root), systemServicesEnabled: false)
        let id = try savedItem(in: store); let before = store.state
        repository.failSave = true
        XCTAssertFalse(store.mutate { try EntityAliasPolicy.add("Another recognized name", to: id, in: &$0) })
        XCTAssertEqual(store.state, before); XCTAssertEqual(repository.state, before)
        repository.failSave = false
        XCTAssertTrue(store.mutate { try EntityAliasPolicy.add("Another recognized name", to: id, in: &$0) })
        let saved = store.state; repository.failSave = true
        XCTAssertFalse(store.mutate { try EntityAliasPolicy.remove("Another recognized name", from: id, in: &$0) })
        XCTAssertEqual(store.state, saved); XCTAssertEqual(repository.state, saved)
        repository.failSave = false
        XCTAssertTrue(store.deleteSource(try XCTUnwrap(store.state.sources.first?.id)))
        let deleted = store.state
        XCTAssertFalse(store.mutate { try EntityAliasPolicy.add("Stale draft alias", to: id, in: &$0) })
        XCTAssertEqual(store.state, deleted)
        XCTAssertTrue(store.error?.contains("removed") == true)
    }

    private func savedItem(in store: AppStore) throws -> UUID {
        let source = try store.capture(title: "Fictional alias source", kind: .typed, text: "Medicine: Fictional base medicine.", analyze: false)
        let claim = Claim(sourceID: source, kind: .medication, label: "Fictional base medicine", quote: "Medicine: Fictional base medicine.")
        XCTAssertTrue(store.accept([claim])); return try XCTUnwrap(store.state.entities.first?.id)
    }
}

@MainActor private final class AliasRepository: CareRepository {
    var state = CareState(); var failSave = false
    func load() throws -> CareState { state }
    func save(_ value: CareState) throws {
        if failSave { throw CareError.invalid("Fictional storage failure") }
        state = value
    }
}
