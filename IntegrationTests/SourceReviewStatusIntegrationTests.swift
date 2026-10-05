import XCTest
import CareCore
@testable import CareContinuity

@MainActor final class SourceReviewStatusIntegrationTests: XCTestCase {
    func testPartialAcceptanceFinalRejectionAndRelaunchShowCurrentReviewCounts() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("CareInOneSourceReviewStatus-" + UUID().uuidString)
        // Keep the isolated temporary store until process exit: SwiftData may retain its coordinator.
        let store = try AppStore(repository: SwiftDataRepository(root: root), vault: EvidenceVault(root: root), systemServicesEnabled: false)
        let (id, reports) = try installReports(in: store)
        let original = try XCTUnwrap(store.source(id))
        let originalFile = try XCTUnwrap(original.originalFile)
        let originalBytes = try Data(contentsOf: store.vault.url(originalFile))
        XCTAssertEqual(status(in: store, sourceID: id)?.pendingCount, 2)

        XCTAssertTrue(store.accept([reports[0]]))
        XCTAssertEqual(status(in: store, sourceID: id)?.pendingCount, 1)
        XCTAssertTrue(status(in: store, sourceID: id)?.message.hasPrefix("1 proposal waiting for review.") == true)
        XCTAssertTrue(store.reject(reports[1]))
        XCTAssertEqual(status(in: store, sourceID: id)?.pendingCount, 0)
        XCTAssertTrue(status(in: store, sourceID: id)?.message.hasPrefix("No proposals waiting for review. 1 reviewed report is saved in My Care.") == true)

        let reopened = try AppStore(repository: SwiftDataRepository(root: root), vault: EvidenceVault(root: root), systemServicesEnabled: false)
        XCTAssertEqual(status(in: reopened, sourceID: id), status(in: store, sourceID: id))
        XCTAssertEqual(reopened.source(id)?.processingMessage, original.processingMessage)
        XCTAssertEqual(reopened.source(id)?.originalText, original.originalText)
        XCTAssertEqual(reopened.source(id)?.previousText, original.previousText)
        XCTAssertEqual(try Data(contentsOf: reopened.vault.url(originalFile)), originalBytes)
        XCTAssertEqual(reopened.state.claims.first { $0.id == reports[0].id }?.quote, reports[0].quote)
        XCTAssertEqual(reopened.state.claims.first { $0.id == reports[1].id }?.review, .rejected)
    }

    func testAllRejectedAndReviewedAgainDoNotKeepInitialProposalCount() throws {
        let repository = SourceStatusRepository()
        let store = try fixture(repository)
        let (id, reports) = try installReports(in: store)
        for report in reports { XCTAssertTrue(store.reject(report)) }
        XCTAssertTrue(status(in: store, sourceID: id)?.message.contains("No reports from this source are saved in My Care.") == true)
        XCTAssertTrue(store.accept([try XCTUnwrap(store.state.claims.first { $0.id == reports[0].id })]))
        XCTAssertEqual(status(in: store, sourceID: id)?.pendingCount, 0)
        XCTAssertEqual(status(in: store, sourceID: id)?.savedReportCount, 1)
        XCTAssertTrue(store.reject(try XCTUnwrap(store.state.claims.first { $0.id == reports[0].id })))
        XCTAssertEqual(status(in: store, sourceID: id)?.savedReportCount, 0)
        XCTAssertEqual(status(in: store, sourceID: id)?.pendingCount, 0)
        XCTAssertFalse(status(in: store, sourceID: id)?.message.contains("2 proposals ready") == true)
    }

    func testFailedReviewSaveRetainsPendingStatusAndOtherSourceDoesNotContribute() throws {
        let repository = SourceStatusRepository()
        let store = try fixture(repository)
        let (id, reports) = try installReports(in: store)
        let other = try store.capture(title: "Unrelated fictional source", kind: .typed, text: "Bring my list.", analyze: false)
        XCTAssertTrue(store.mutate { $0.claims.append(Claim(sourceID: other, kind: .instruction, label: "Bring list", quote: "Bring my list.")) })
        let before = store.state
        let beforeStatus = status(in: store, sourceID: id)
        repository.failSave = true
        XCTAssertFalse(store.accept([reports[0]]))
        XCTAssertFalse(store.reject(reports[1]))
        XCTAssertEqual(store.state, before)
        XCTAssertEqual(status(in: store, sourceID: id), beforeStatus)
        XCTAssertEqual(beforeStatus?.pendingCount, 2)
    }

    private func status(in store: AppStore, sourceID: UUID) -> SourceReviewStatus? {
        store.source(sourceID).map { SourceReviewStatus(source: $0, claims: store.state.claims) }
    }
    private func fixture(_ repository: SourceStatusRepository) throws -> AppStore {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("CareInOneSourceStatusMemory-" + UUID().uuidString)
        addTeardownBlock { try? FileManager.default.removeItem(at: root) }
        return try AppStore(repository: repository, vault: EvidenceVault(root: root), systemServicesEnabled: false)
    }
    private func installReports(in store: AppStore) throws -> (UUID, [Claim]) {
        let text = "Allergy: latex.\nAllergy: penicillin."
        let id = try store.capture(title: "Fictional current review status", kind: .textFile, text: text, data: Data(text.utf8), extension: "txt", analyze: false)
        var first = Claim(sourceID: id, kind: .allergy, label: "latex", quote: "Allergy: latex.")
        first.userEdited = true; first.confidence = 1
        var second = Claim(sourceID: id, kind: .allergy, label: "penicillin", quote: "Allergy: penicillin.")
        second.userEdited = true; second.confidence = 1
        let reports = [first, second]
        XCTAssertTrue(store.mutate { state in
            state.claims += reports
            guard let index = state.sources.firstIndex(where: { $0.id == id }) else { throw CareError.invalid("Fictional source missing") }
            state.sources[index].state = .needsReview
            state.sources[index].analysisVersion = "fictional-analysis"
            state.sources[index].processingMessage = "2 proposals ready. Nothing enters My Care until you review it."
        })
        return (id, reports)
    }
}

@MainActor private final class SourceStatusRepository: CareRepository {
    var state = CareState()
    var failSave = false
    func load() throws -> CareState { state }
    func save(_ value: CareState) throws {
        if failSave { throw CareError.invalid("Fictional review storage failure") }
        state = value
    }
}
