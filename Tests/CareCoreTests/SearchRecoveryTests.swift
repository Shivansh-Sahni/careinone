import Testing
@testable import CareCore

struct SearchRecoveryTests {
    @Test func PreservedOriginalAndEarlierWorkingTextStayFindableWithoutBecomingReviewedCare() {
        var state = CareState()
        var source = Source(title: "Fictional visit", kind: .typed, text: "Original allergy: latex", contentHash: "synthetic")
        source.workingText = "Corrected allergy: penicillin"
        source.previousText = ["Earlier question about sleep"]
        state.sources = [source]
        let original = SearchEngine.search("latex", state: state)
        #expect(original.count == 1)
        #expect(original.first?.type == "Source · original text")
        #expect(original.first?.excerpt.contains("latex") == true)
        #expect(original.first?.sourceID == source.id)
        #expect(SearchEngine.search("sleep", state: state).first?.type == "Source · earlier text 1")
        #expect(SearchEngine.search("penicillin", state: state).first?.type == "Source · working text")
        #expect(state.claims.isEmpty && state.entities.isEmpty)
    }
    @Test func RemovingSourceRemovesItsHistoricalSearchResults() {
        var state = CareState()
        var source = Source(title: "Fictional original", kind: .typed, text: "Migraine history", contentHash: "synthetic")
        source.workingText = "Updated note"
        state.sources = [source]
        #expect(!SearchEngine.search("migraine", state: state).isEmpty)
        Reconciler.deleteSource(source.id, from: &state)
        #expect(SearchEngine.search("migraine", state: state).isEmpty)
    }
}
