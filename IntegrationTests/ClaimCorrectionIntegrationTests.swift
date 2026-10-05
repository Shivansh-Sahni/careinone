import XCTest
import CareCore
@testable import CareContinuity

@MainActor final class ClaimCorrectionIntegrationTests: XCTestCase {
    func testCorrectedReportPreservesEvidenceAndEarlierVersionAcrossRelaunch() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("CareInOneClaimCorrection-" + UUID().uuidString)
        // SwiftData can retain its SQLite coordinator after container release.
        // Keep this isolated temporary fixture until the test process exits.
        let store = try AppStore(repository: SwiftDataRepository(root: root), vault: EvidenceVault(root: root), systemServicesEnabled: false)
        let original = try savedClaim(in: store)
        var correction = original
        correction.label = "penicillin"; correction.quote = "Allergy: penicillin."; correction.entityID = nil
        XCTAssertTrue(store.correctReviewedClaim(original, with: correction))
        XCTAssertEqual(store.state.claims.filter(\.canonical).map(\.label), ["penicillin"])
        XCTAssertTrue(store.state.claims.contains { !$0.canonical && $0.label == "latex" && $0.quote == original.quote })
        XCTAssertEqual(store.state.claims.first { $0.id == original.id }?.revision, original.revision + 1)
        XCTAssertEqual(store.source(original.sourceID)?.originalText, "Allergy: latex.\nAllergy: penicillin.")
        let reopened = try AppStore(repository: SwiftDataRepository(root: root), vault: EvidenceVault(root: root), systemServicesEnabled: false)
        XCTAssertEqual(reopened.state.claims.filter(\.canonical).map(\.label), ["penicillin"])
        XCTAssertTrue(reopened.state.claims.contains { !$0.canonical && $0.label == "latex" })
    }
    func testWithdrawalRebuildsCareAndCanBeReviewedAgain() throws {
        let repository = CorrectionRepository()
        let store = try fixture(repository)
        let original = try savedClaim(in: store)
        XCTAssertFalse(store.state.entities.isEmpty)
        XCTAssertTrue(store.reject(original))
        XCTAssertTrue(store.state.claims.filter(\.canonical).isEmpty)
        XCTAssertTrue(store.state.entities.isEmpty)
        XCTAssertTrue(store.state.loops.isEmpty)
        XCTAssertNotNil(store.source(original.sourceID))
        var recovered = try XCTUnwrap(store.state.claims.first { $0.id == original.id })
        recovered.entityID = nil
        XCTAssertTrue(store.accept([recovered]))
        XCTAssertEqual(store.state.claims.filter(\.canonical).map(\.label), ["latex"])
    }
    func testCorrectionFailureRetainsPreviousCommittedReportAndNoFalseHistory() throws {
        let repository = CorrectionRepository()
        let store = try fixture(repository)
        let original = try savedClaim(in: store)
        let before = store.state
        var correction = original; correction.value = "Corrected wording"
        repository.failSave = true
        XCTAssertFalse(store.correctReviewedClaim(original, with: correction))
        XCTAssertEqual(store.state, before)
        repository.failSave = false
        correction.quote = "A passage that was never recorded"
        XCTAssertFalse(store.correctReviewedClaim(original, with: correction))
        XCTAssertEqual(store.state, before)
    }
    func testStaleCorrectionAndWithdrawalCannotOverwriteNewerReview() throws {
        let store = try fixture(CorrectionRepository())
        let original = try savedClaim(in: store)
        var correction = original; correction.value = "Patient corrected wording"
        XCTAssertTrue(store.correctReviewedClaim(original, with: correction))
        let newer = store.state
        XCTAssertFalse(store.correctReviewedClaim(original, with: original))
        XCTAssertFalse(store.reject(original))
        XCTAssertEqual(store.state, newer)
    }
    private func fixture(_ repository: CorrectionRepository) throws -> AppStore {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("CareInOneCorrectionMemory-" + UUID().uuidString)
        addTeardownBlock { try? FileManager.default.removeItem(at: root) }
        return try AppStore(repository: repository, vault: EvidenceVault(root: root), systemServicesEnabled: false)
    }
    private func savedClaim(in store: AppStore) throws -> Claim {
        let id = try store.capture(title: "Fictional allergy correction", kind: .typed, text: "Allergy: latex.\nAllergy: penicillin.", analyze: false)
        var claim = Claim(sourceID: id, kind: .allergy, label: "latex", quote: "Allergy: latex.")
        claim.userEdited = true; claim.confidence = 1
        XCTAssertTrue(store.accept([claim]))
        return try XCTUnwrap(store.state.claims.first { $0.id == claim.id })
    }
}

@MainActor private final class CorrectionRepository: CareRepository {
    var state = CareState()
    var failSave = false
    func load() throws -> CareState { state }
    func save(_ value: CareState) throws {
        if failSave { throw CareError.invalid("Synthetic storage failure") }
        state = value
    }
}
