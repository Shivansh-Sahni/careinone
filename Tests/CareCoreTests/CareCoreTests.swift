import Foundation
import Testing
@testable import CareCore

struct CareCoreTests {
    let day = Date(timeIntervalSince1970: 1_780_000_000)
    func fixture(_ texts: [String] = ["metoprolol 25 mg oral daily", "metoprolol 50 mg oral daily"]) -> CareState {
        var state = CareState()
        state.sources = texts.enumerated().map { index, text in Source(title: "Source \(index)", kind: .typed, text: text, contentHash: ContentHasher.hash(text), eventAt: day.addingTimeInterval(Double(index) * 86400)) }
        return state
    }
    func claim(_ state: CareState, _ i: Int = 0, kind: EntityKind = .medication, label: String = "metoprolol", action: ClaimAction = .taking) -> Claim {
        let s = state.sources[i]; var c = Claim(sourceID: s.id, kind: kind, label: label, quote: s.workingText)
        c.action = action; c.eventAt = s.eventAt; c.confidence = 0.9
        return c
    }
    @Test func proposalsCannotBecomeCanonical() throws {
        var state = fixture(); state.claims = try LocalExtractor.proposals(state.sources[0]); Reconciler.rebuild(&state)
        #expect(state.entities.isEmpty); #expect(state.loops.isEmpty); #expect(state.changes.isEmpty)
    }
    @Test func dosageDisagreementPersistsWithoutChoosingWinner() throws {
        var s = fixture(); var a = claim(s); a.numericValue = 25; a.unit = "mg"
        var b = claim(s, 1); b.numericValue = 50; b.unit = "mg"
        try Reconciler.accept([a, b], into: &s, now: day)
        #expect(s.entities.count == 1); #expect(s.conflicts.count == 1); #expect(s.claims.filter(\.canonical).count == 2)
        #expect(s.projection(for: s.entities[0].id) == .conflicting)
        let old = s; Reconciler.rebuild(&s, now: day); #expect(s == old)
    }
    @Test func normalizedUnitsDoNotConflict() throws {
        var s = fixture(); var a = claim(s); a.numericValue = 0.025; a.unit = "g"
        var b = claim(s, 1); b.numericValue = 25; b.unit = "mg"
        try Reconciler.accept([a, b], into: &s); #expect(s.conflicts.isEmpty)
    }
    @Test(arguments: ["route", "frequency", "form", "status"])
    func medicationDimensions(field: String) throws {
        var s = fixture(); var a = claim(s); var b = claim(s, 1)
        switch field { case "route": a.route = "oral"; b.route = "topical"; case "frequency": a.frequency = "daily"; b.frequency = "twice daily"; case "form": a.form = "tablet"; b.form = "liquid"; default: b.action = .stopped }
        try Reconciler.accept([a, b], into: &s); #expect(s.conflicts.count == 1)
    }
    @Test func rejectionAndOtherSubjectStayOut() throws {
        var s = fixture(["Mother has hypertension"]); var a = claim(s, kind: .condition, label: "hypertension"); a.subject = .family
        #expect(throws: CareError.self) { try Reconciler.accept([a], into: &s) }
        a.review = .rejected; s.claims = [a]; Reconciler.rebuild(&s); #expect(s.entities.isEmpty)
    }
    @Test func forgedQuoteRejectedAtomically() throws {
        var s = fixture(); var a = claim(s); a.quote = "not in source"; let old = s
        #expect(throws: CareError.self) { try Reconciler.accept([claim(s), a], into: &s) }; #expect(s == old)
    }
    @Test func wrongPageRejected() throws {
        var s = fixture(); s.sources[0].pages = [EvidencePage(number: 1, text: "different")]
        var c = claim(s); c.page = 1
        #expect(throws: CareError.self) { try ProposalValidator.validate(c, source: s.sources[0]) }
    }
    @Test func invalidNumbersRejected() throws {
        let s = fixture(); var c = claim(s); c.numericValue = .infinity
        #expect(throws: CareError.self) { try ProposalValidator.validate(c, source: s.sources[0]) }
        c.numericValue = nil; c.confidence = 1.1
        #expect(throws: CareError.self) { try ProposalValidator.validate(c, source: s.sources[0]) }
    }
    @Test func supersessionRequiresPatientEdit() throws {
        var s = fixture(); var a = claim(s); a.numericValue = 25; a.unit = "mg"; try Reconciler.accept([a], into: &s)
        var b = claim(s, 1); b.numericValue = 50; b.unit = "mg"; b.supersedesID = a.id
        #expect(throws: CareError.self) { try Reconciler.accept([b], into: &s) }
        b.userEdited = true; try Reconciler.accept([b], into: &s)
        #expect(s.conflicts.isEmpty); #expect(s.relations.contains { $0.kind == .supersedes })
    }
    @Test func missingMedicationNeverMeansStopped() throws {
        var s = fixture(["metoprolol 25 mg", "Follow up in two weeks"]); let a = claim(s)
        try Reconciler.accept([a, claim(s, 1, kind: .followUp, label: "Cardiology", action: .requested)], into: &s)
        #expect(s.claims.first { $0.id == a.id }?.action == .taking)
    }
    @Test func laterUploadIsNotLaterEvent() throws {
        var s = fixture(); s.sources[1].eventAt = nil; var a = claim(s); a.numericValue = 25
        var b = claim(s, 1); b.numericValue = 50; try Reconciler.accept([a, b], into: &s)
        #expect(s.conflicts.count == 1); #expect(s.claims.first { $0.id == b.id }?.eventAt == nil)
    }
    @Test func weakMatchesRequireReview() {
        let entity = Entity(kind: .medication, label: "metoprolol succinate")
        let s = fixture(); let c = claim(s, label: "metoprolol tartrate")
        let candidates = EntityResolver.candidates(for: c, in: [entity]); #expect(candidates.allSatisfy { !$0.automatic })
    }
    @Test func codeAndAliasMatching() {
        var e = Entity(kind: .medication, label: "brand"); e.code = "123"; e.codeSystem = "rx"; e.aliases = ["generic"]
        let s = fixture(); var c = claim(s, label: "generic")
        #expect(EntityResolver.candidates(for: c, in: [e]).first?.automatic == true)
        c.label = "different"; c.code = "123"; c.codeSystem = "other"
        #expect(EntityResolver.candidates(for: c, in: [e]).isEmpty)
        c.codeSystem = "rx"; #expect(EntityResolver.candidates(for: c, in: [e]).first?.automatic == true)
    }
    @Test func conditionalMRIIsNotAnOrder() throws {
        var s = fixture(["Consider MRI if needed"]); let proposals = try LocalExtractor.proposals(s.sources[0])
        #expect(proposals[0].conditional); try Reconciler.accept(proposals, into: &s); #expect(s.loops.isEmpty)
    }
    @Test func mentionedTestDoesNotOpenLoop() throws {
        var s = fixture(); try Reconciler.accept([claim(s, kind: .labTest, label: "CBC", action: .mentioned)], into: &s); #expect(s.loops.isEmpty)
    }
    @Test func testCompletesOnlyWhenResultAvailable() throws {
        var s = fixture(["CBC ordered", "CBC completed", "CBC result available"])
        try Reconciler.accept([claim(s, kind: .labTest, label: "CBC", action: .ordered), claim(s, 1, kind: .labTest, label: "CBC", action: .completed)], into: &s)
        #expect(s.loops[0].status == .open); #expect(s.loops[0].stage == .completed)
        try Reconciler.accept([claim(s, 2, kind: .labTest, label: "CBC", action: .resultAvailable)], into: &s)
        #expect(s.loops[0].status == .completed)
    }
    @Test func undatedCompletionDoesNotSilentlyCloseOtherEncounter() throws {
        var s = fixture(["CBC ordered", "CBC completed"]); s.sources[1].eventAt = nil
        try Reconciler.accept([claim(s, kind: .labTest, label: "CBC", action: .ordered), claim(s, 1, kind: .labTest, label: "CBC", action: .resultAvailable)], into: &s)
        #expect(s.loops[0].status == .uncertain)
    }
    @Test func approximateDatesNeverSayOverdue() {
        let l = CareLoop(id: "x", entityID: UUID(), kind: .test, title: "CBC", stage: .ordered, claimIDs: [], dueAt: day, precision: .approximate, createdAt: day)
        #expect(!l.timing(now: day.addingTimeInterval(86400)).contains("passed")); #expect(!l.timing().contains("overdue"))
    }
    @Test func intervalUsesMedicalEventNotUpload() throws {
        var s = fixture(["Follow up in 2 weeks"]); let p = try LocalExtractor.proposals(s.sources[0]); try Reconciler.accept(p, into: &s)
        #expect(abs(s.loops[0].dueAt!.timeIntervalSince(day) - 14 * 86400) < 3601)
        s = fixture(["Follow up in 2 weeks"]); s.sources[0].eventAt = nil
        try Reconciler.accept(LocalExtractor.proposals(s.sources[0]), into: &s); #expect(s.loops[0].dueAt == nil)
    }
    @Test func duplicateLoopSuppression() throws {
        var s = fixture(["CBC ordered", "CBC ordered"])
        try Reconciler.accept([claim(s, kind: .labTest, label: "CBC", action: .ordered), claim(s, 1, kind: .labTest, label: "CBC", action: .ordered)], into: &s)
        #expect(s.loops.count == 1)
    }
    @Test func userCompletionIsDistinctAndRebuildable() throws {
        var s = fixture(); try Reconciler.accept([claim(s, kind: .followUp, label: "PCP", action: .requested)], into: &s)
        var o = LoopOverride(); o.status = .completed; o.evidenceIDs = s.loops[0].claimIDs; s.loopOverrides[s.loops[0].id] = o
        Reconciler.rebuild(&s); #expect(s.loops[0].userCompleted); #expect(s.loops[0].timing().contains("your report"))
    }
    @Test(arguments: [EntityKind.referral, .followUp, .procedure, .administrativeTask, .resultType])
    func allLoopMachines(kind: EntityKind) throws {
        var s = fixture(["requested", "completed"])
        let first: ClaimAction = kind == .procedure ? .planned : .requested
        let last: ClaimAction = kind == .referral ? .visitCompleted : .completed
        try Reconciler.accept([claim(s, kind: kind, label: "Item", action: first), claim(s, 1, kind: kind, label: "Item", action: last)], into: &s)
        #expect(s.loops.count == 1); #expect(s.loops[0].status == .completed)
    }
    @Test func conflictResolutionPersistsAndNewEvidenceReopensInbox() throws {
        var s = fixture(["dose 25", "dose 50", "dose 75"])
        var a = claim(s); a.numericValue = 25; var b = claim(s, 1); b.numericValue = 50
        try Reconciler.accept([a, b], into: &s); s.conflicts[0].status = .clarified; s.conflicts[0].note = "Asked clinician"
        Reconciler.rebuild(&s); #expect(s.conflicts[0].status == .clarified)
        var c = claim(s, 2); c.numericValue = 75; try Reconciler.accept([c], into: &s)
        #expect(s.conflicts.filter { $0.status == .unresolved }.count == 2)
    }
    @Test func deletionRebuildsAndCascades() throws {
        var s = fixture(); var a = claim(s); a.numericValue = 25; var b = claim(s, 1); b.numericValue = 50
        try Reconciler.accept([a, b], into: &s); s.questions = [Question(text: "Why?", sourceID: s.sources[1].id)]
        Reconciler.deleteSource(s.sources[1].id, from: &s)
        #expect(s.conflicts.isEmpty); #expect(s.claims.count == 1); #expect(s.questions.isEmpty); #expect(s.changes.allSatisfy { $0.sourceID == s.sources[0].id })
    }
    @Test func chunkingPreservesOverlapAndUnicode() {
        let input = String(repeating: "❤️αβ", count: 100)
        let chunks = Chunker.split(input, size: 30, overlap: 5)
        #expect(chunks.count > 1); #expect(String(chunks[0].text.suffix(5)) == String(chunks[1].text.prefix(5)))
        #expect(Chunker.split(input, size: 3, overlap: 3).isEmpty)
    }
    @Test func clarificationIsBounded() throws {
        let s = fixture(); let c = try LocalExtractor.proposals(s.sources[0])
        #expect(ProposalValidator.clarifications(c + c + c + c).count <= 3)
    }
    @Test func cacheInvalidatesOnEventDateAndVersion() {
        var s = fixture().sources[0]; let key = ContentHasher.cacheKey(s, version: "a"); s.eventAt = nil
        #expect(ContentHasher.cacheKey(s, version: "a") != key); #expect(ContentHasher.cacheKey(s, version: "a") != ContentHasher.cacheKey(s, version: "b"))
    }
    @Test func priorityExplainsConsequentialConflict() throws {
        var s = fixture(); var a = claim(s); a.numericValue = 25; var b = claim(s, 1); b.numericValue = 50
        try Reconciler.accept([a, b], into: &s, now: day)
        let top = PriorityEngine.items(s, now: day).first
        #expect(top?.destination == "discrepancies"); #expect(top?.score == 100); #expect(top?.sourceID != nil)
    }
    @Test func roundTripMaintainsGraph() throws {
        var s = fixture(); try Reconciler.accept([claim(s)], into: &s)
        let data = try JSONEncoder().encode(s); let decoded = try JSONDecoder().decode(CareState.self, from: data); #expect(decoded == s)
    }
    @Test func fhirRejectsMultiplePatients() throws {
        let data = Data(#"{"resourceType":"Bundle","entry":[{"resource":{"resourceType":"Patient","id":"a"}},{"resource":{"resourceType":"Patient","id":"b"}}]}"#.utf8)
        #expect(throws: CareError.self) { try FHIRImporter.parse(data, sourceID: UUID()) }
    }
    @Test func fhirUnknownSubjectRequiresReview() throws {
        let data = Data(#"{"resourceType":"Observation","status":"final","code":{"text":"A1c"},"valueQuantity":{"value":5.7,"unit":"%"}}"#.utf8)
        let parsed = try FHIRImporter.parse(data, sourceID: UUID()); #expect(parsed.claims[0].subject == .unknown); #expect(parsed.claims[0].needsStrongReview)
    }
    @Test func fhirPreservesValueAndSubject() throws {
        let data = Data(#"{"resourceType":"Bundle","entry":[{"resource":{"resourceType":"Patient","id":"p"}},{"resource":{"resourceType":"Observation","status":"final","subject":{"reference":"Patient/p"},"code":{"text":"A1c"},"valueQuantity":{"value":5.7,"unit":"%"}}}]}"#.utf8)
        let parsed = try FHIRImporter.parse(data, sourceID: UUID()); #expect(parsed.claims[0].numericValue == 5.7); #expect(parsed.claims[0].subject == .patient); #expect(parsed.text.contains(parsed.claims[0].quote))
    }
}
