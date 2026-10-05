import Foundation
import Testing
@testable import CareCore

struct SourceReviewStatusTests {
    private func fixture() -> (Source, [Claim]) {
        var source = Source(title: "Fictional review status", kind: .typed, text: "Allergy: latex.\nAllergy: penicillin.", contentHash: "fictional-review-status")
        source.state = .needsReview
        source.analysisVersion = "fictional-analysis"
        source.processingMessage = "2 proposals ready. Nothing enters My Care until you review it."
        return (source, [
            Claim(sourceID: source.id, kind: .allergy, label: "latex", quote: "Allergy: latex."),
            Claim(sourceID: source.id, kind: .allergy, label: "penicillin", quote: "Allergy: penicillin.")
        ])
    }

    @Test func currentPartialReviewAndRejectionReplaceHistoricalExtractionCount() throws {
        let (source, claims) = fixture()
        var state = CareState(); state.sources = [source]; state.claims = claims
        let initial = SourceReviewStatus(source: source, claims: state.claims)
        #expect(initial.pendingCount == 2)
        #expect(initial.message.hasPrefix("2 proposals waiting for review."))
        try Reconciler.accept([claims[0]], into: &state)
        let partial = SourceReviewStatus(source: source, claims: state.claims)
        #expect(partial.pendingCount == 1); #expect(partial.savedReportCount == 1)
        #expect(partial.message.hasPrefix("1 proposal waiting for review."))
        #expect(!partial.message.contains("2 proposals ready"))
        state.claims[1].review = .rejected
        let complete = SourceReviewStatus(source: source, claims: state.claims)
        #expect(complete.pendingCount == 0); #expect(complete.savedReportCount == 1)
        #expect(complete.message.hasPrefix("No proposals waiting for review. 1 reviewed report is saved in My Care."))
        #expect(state.sources[0] == source) // Presentation never rewrites original evidence or status history.
    }

    @Test func withdrawnAndNonPatientReportsDoNotAppearSavedInMyCare() {
        var (source, claims) = fixture(); source.state = .complete
        claims[0].review = .rejected
        claims[1].review = .accepted; claims[1].subject = .family
        let status = SourceReviewStatus(source: source, claims: claims)
        #expect(status.pendingCount == 0); #expect(status.savedReportCount == 0)
        #expect(status.message.contains("No reports from this source are saved in My Care."))
        var pending = claims[0]; pending.id = UUID(); pending.review = .pending
        let rereview = SourceReviewStatus(source: source, claims: claims + [pending])
        #expect(rereview.pendingCount == 1)
        #expect(rereview.message.hasPrefix("1 proposal waiting for review."))
    }

    @Test func sourceScopeAndDecodedReviewStatesRemainAuthoritative() throws {
        let (source, claims) = fixture()
        var state = CareState(); state.sources = [source]; state.claims = claims
        let other = Source(title: "Other fictional patient source", kind: .typed, text: "Unrelated", contentHash: "other-fictional")
        state.sources.append(other)
        state.claims.append(Claim(sourceID: other.id, kind: .other, label: "Other", quote: "Unrelated"))
        try Reconciler.accept(claims, into: &state)
        let decoded = try JSONDecoder().decode(CareState.self, from: JSONEncoder().encode(state))
        let status = SourceReviewStatus(source: try #require(decoded.source(source.id)), claims: decoded.claims)
        #expect(status.pendingCount == 0); #expect(status.savedReportCount == 2)
        #expect(status.message.contains("2 reviewed reports are saved in My Care."))
        #expect(decoded.source(source.id)?.processingMessage == source.processingMessage)
        #expect(decoded.source(source.id)?.originalText == source.originalText)
    }

    @Test func analysisLimitAndUnsupportedFHIRWarningsSurviveReview() {
        var (source, claims) = fixture()
        let limit = "This source reached the 200-item analysis limit. Split the source or review the remaining original text manually."
        source.processingMessage += " " + limit
        claims = claims.map { var claim = $0; claim.review = .accepted; return claim }
        #expect(SourceReviewStatus(source: source, claims: claims).message.hasSuffix(limit))
        source.kind = .fhir
        source.processingMessage = "2 supported items. 3 unsupported resources preserved only in the original file. Confirm subject and extraction."
        let imported = SourceReviewStatus(source: source, claims: claims)
        #expect(imported.message.contains("3 unsupported resources preserved only in the original file."))
        #expect(!imported.message.contains("2 supported items"))
        #expect(!imported.message.contains("Confirm subject"))
        source.processingMessage = "0 new proposals. 3 unsupported resources remain in the original file."
        #expect(SourceReviewStatus(source: source, claims: claims).message.hasSuffix("3 unsupported resources remain in the original file."))
    }

    @Test func failedCancelledProcessingAndEditedEvidenceKeepRecoveryInstructions() {
        var (source, claims) = fixture()
        for state in [ProcessingState.failed, .cancelled, .processing, .pending, .saved] {
            source.state = state
            source.processingMessage = "Fictional recovery instructions; the current request did not finish."
            #expect(SourceReviewStatus(source: source, claims: claims).message == source.processingMessage)
        }
        source.state = .pending
        source.processingMessage = "Working text or event date changed. Analyze the updated source, then review new proposals."
        claims = claims.map { var claim = $0; claim.review = .rejected; return claim }
        #expect(SourceReviewStatus(source: source, claims: claims).message == source.processingMessage)
        source.processingMessage = ""
        #expect(SourceReviewStatus(source: source, claims: claims).message == "Your source is preserved on this device.")
    }
}
