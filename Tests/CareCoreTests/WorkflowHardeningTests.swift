import Foundation
import Testing
@testable import CareCore

struct WorkflowHardeningTests {
    @Test func largeIntervalsDoNotOverflowOrInventDates() throws {
        let text = "Follow up in 9223372036854775807 weeks"
        let source = Source(title: "Synthetic", kind: .typed, text: text, contentHash: ContentHasher.hash(Data(text.utf8)), eventAt: Date())
        let claims = try LocalExtractor.proposals(source)
        #expect(!claims.isEmpty); #expect(claims.allSatisfy { $0.intervalDays == nil && $0.dueAt == nil })
    }
    @Test func askDoesNotReturnUnrelatedClaimsFromMatchingSource() async throws {
        let text = "Medication: metoprolol 25 mg daily\nAllergy: penicillin"
        let source = Source(title: "Synthetic", kind: .typed, text: text, contentHash: ContentHasher.hash(Data(text.utf8)))
        var state = CareState(); state.sources = [source]
        try Reconciler.accept(LocalExtractor.proposals(source), into: &state)
        let answer = try await LocalGroundedSynthesis().answer("What is saved about metoprolol?", state: state)
        #expect(!answer.isEmpty); #expect(answer.allSatisfy { !$0.summary.lowercased().contains("penicillin") })
        #expect(try await LocalGroundedSynthesis().answer("show me my saved care", state: state).isEmpty)
    }
    @Test func searchIncludesReviewedValuesBeyondRawSourceText() throws {
        let source = Source(title: "Synthetic note", kind: .typed, text: "The medication name needs review.", contentHash: "test")
        var claim = Claim(sourceID: source.id, kind: .medication, label: "Metoprolol", quote: source.workingText)
        claim.value = "patient corrected spelling"; claim.userEdited = true
        var state = CareState(); state.sources = [source]; try Reconciler.accept([claim], into: &state)
        #expect(SearchEngine.search("corrected", state: state).contains { $0.type == "Reviewed claim" })
        #expect(SearchEngine.search("top", state: state).isEmpty)
    }
}
