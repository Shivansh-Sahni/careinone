import Foundation
import Testing
@testable import CareCore

struct EntityAliasPolicyTests {
    private func example() throws -> (CareState, UUID) {
        let source = Source(title: "Fictional alias evidence", kind: .typed, text: "Medicine: Fictional base medicine.", contentHash: "fictional")
        let claim = Claim(sourceID: source.id, kind: .medication, label: "Fictional base medicine", quote: source.workingText)
        var state = CareState(); state.sources = [source]; try Reconciler.accept([claim], into: &state)
        return (state, try #require(state.entities.first?.id))
    }

    @Test func caseAndWhitespaceDuplicatesCannotAddFalseHistory() throws {
        var (state, id) = try example()
        try EntityAliasPolicy.add("  Another\n recognized\tname  ", to: id, in: &state)
        #expect(state.entity(id)?.aliases == ["Another recognized name"])
        let saved = state
        #expect(throws: CareError.self) { try EntityAliasPolicy.add("ANOTHER   RECOGNIZED NAME", to: id, in: &state) }
        #expect(state == saved)
        #expect(throws: CareError.self) { try EntityAliasPolicy.add("  fictional BASE medicine ", to: id, in: &state) }
        #expect(state == saved)
    }

    @Test func removingAliasChangesFutureMatchingWithoutRewritingReviewedCare() throws {
        var (state, id) = try example(); let claims = state.claims; let sources = state.sources; let relations = state.relations
        try EntityAliasPolicy.add("Another recognized name", to: id, in: &state)
        let future = Claim(sourceID: sources[0].id, kind: .medication, label: "another RECOGNIZED name", quote: "Future fictional evidence")
        #expect(EntityResolver.candidates(for: future, in: state.entities).contains { $0.id == id && $0.automatic })
        try EntityAliasPolicy.remove("Another recognized name", from: id, in: &state)
        #expect(!EntityResolver.candidates(for: future, in: state.entities).contains { $0.id == id && $0.automatic })
        #expect(state.claims == claims); #expect(state.sources == sources); #expect(state.relations == relations)
        #expect(state.claims(for: id).count == 1)
    }

    @Test func legacyDuplicateRemovalPreservesOtherAliasesAndCanonicalAssociation() throws {
        var (state, id) = try example()
        state.entities[0].aliases = ["  Other Name ", "OTHER  NAME", "Distinct alias", "---"]
        let claims = state.claims
        try EntityAliasPolicy.remove("other name", from: id, in: &state)
        #expect(state.entity(id)?.aliases == ["Distinct alias", "---"])
        try EntityAliasPolicy.remove("---", from: id, in: &state)
        #expect(state.entity(id)?.aliases == ["Distinct alias"])
        #expect(state.claims == claims)
    }

    @Test func emptyNamesAndStaleItemOrAliasCannotReportSuccess() throws {
        var (state, id) = try example(); let before = state
        for raw in [" \n\t ", "---"] {
            #expect(throws: CareError.self) { try EntityAliasPolicy.add(raw, to: id, in: &state) }
            #expect(state == before)
        }
        #expect(throws: CareError.self) { try EntityAliasPolicy.remove("Missing alias", from: id, in: &state) }
        #expect(state == before)
        let missing = UUID()
        #expect(throws: CareError.self) { try EntityAliasPolicy.add("New alias", to: missing, in: &state) }
        #expect(throws: CareError.self) { try EntityAliasPolicy.remove("New alias", from: missing, in: &state) }
        #expect(state == before)
    }
}
