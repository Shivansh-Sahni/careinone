import Foundation
import Testing
@testable import CareCore

struct ContinuityTests {
    private func add(_ text: String, kind: EntityKind = .medication, action: ClaimAction = .taking, number: Double? = nil, into state: inout CareState) throws -> Claim {
        let source = Source(title: text, kind: .typed, text: text, contentHash: ContentHasher.hash(text))
        state.sources.append(source)
        var claim = Claim(sourceID: source.id, kind: kind, label: kind == .medication ? "Metoprolol" : "CBC", quote: text)
        claim.action = action; claim.numericValue = number; claim.unit = number == nil ? "" : "mg"
        try Reconciler.accept([claim], into: &state)
        return try #require(state.claims.first { $0.id == claim.id })
    }
    @Test func previewIsPureAndPredictsConflictWithoutChoosingWinner() throws {
        var state = CareState(); _ = try add("First source: 25 mg", number: 25, into: &state)
        let source = Source(title: "Another report", kind: .typed, text: "Second source: 50 mg", contentHash: "hash")
        state.sources.append(source)
        var draft = Claim(sourceID: source.id, kind: .medication, label: "Metoprolol", quote: source.workingText)
        draft.action = .taking; draft.numericValue = 50; draft.unit = "mg"
        let before = state
        let preview = try EvidenceImpact.accepting([draft], in: state)
        #expect(state == before)
        #expect(preview.differences.contains { $0.kind == .conflictOpened })
        #expect(preview.beforeClaimCount == 1 && preview.afterClaimCount == 2)
        try Reconciler.accept([draft], into: &state)
        #expect(state.conflicts.filter { $0.status == .unresolved }.count == 1)
        #expect(state.claims.filter(\.canonical).count == 2)
    }
    @Test func invalidPreviewLeavesPendingAndCanonicalStateUnchanged() throws {
        var state = CareState(); let accepted = try add("Allergy: latex", kind: .allergy, into: &state)
        var bad = accepted; bad.id = UUID(); bad.quote = "Fabricated supporting quote"
        let before = state
        #expect(throws: CareError.self) { try EvidenceImpact.accepting([bad], in: state) }
        #expect(state == before)
    }
    @Test func olderMedicalEventIsStillNewSavedKnowledgeAndPendingIsExcluded() throws {
        var state = CareState()
        let checkpoint = ContinuityEngine.snapshot(state, title: "Now", now: Date(timeIntervalSince1970: 2000))
        let source = Source(title: "Old report", kind: .typed, text: "Allergy: latex", contentHash: "old", eventAt: Date(timeIntervalSince1970: 100))
        state.sources.append(source)
        var draft = Claim(sourceID: source.id, kind: .allergy, label: "latex", quote: source.workingText)
        draft.eventAt = source.eventAt; state.claims.append(draft)
        #expect(ContinuityComparator.compare(checkpoint, to: state).differences.isEmpty)
        try Reconciler.accept([draft], into: &state, now: Date(timeIntervalSince1970: 3000))
        let change = try #require(ContinuityComparator.compare(checkpoint, to: state).differences.first { $0.kind == .reportAdded })
        #expect(change.explanation.contains("happened earlier")); #expect(change.after?.contains("Patient reported") == true)
    }
    @Test func editedUncertaintyAndSupersessionAreCompared() throws {
        var state = CareState(); var first = try add("Patient reports 25 mg", number: 25, into: &state)
        let checkpoint = ContinuityEngine.snapshot(state, title: "Before")
        first.certainty = .uncertain; first.userEdited = true
        try Reconciler.accept([first], into: &state)
        let difference = try #require(ContinuityComparator.compare(checkpoint, to: state).differences.first { $0.kind == .reportEdited })
        #expect(difference.after?.contains("Uncertain") == true)
        #expect(difference.before?.contains("Patient reports 25 mg") == true)
    }
    @Test func deletingEvidenceDoesNotPretendAWorkflowCompleted() throws {
        var state = CareState(); let claim = try add("CBC ordered at visit", kind: .labTest, action: .ordered, into: &state)
        let before = state
        let comparison = try EvidenceImpact.deleting(claim.sourceID, in: state)
        #expect(state == before)
        #expect(comparison.differences.contains { $0.kind == .loopRemoved })
        #expect(!comparison.differences.contains { $0.kind == .loopCompleted })
        #expect(comparison.differences.contains { $0.explanation.contains("not been marked medically completed") })
    }
    @Test func deletionPurgesCachedQuotesAndSuppressesInvalidBaselineComparisons() throws {
        var state = CareState(); let first = try add("PRIVATE_SOURCE_SENTENCE: 25 mg", number: 25, into: &state)
        _ = try add("Separate document reports 50 mg", number: 50, into: &state)
        let id = try ContinuityEngine.saveCheckpoint(title: "Before deletion", in: &state)
        Reconciler.deleteSource(first.sourceID, from: &state)
        try CareArchive(state: state, files: [:]).validate()
        let json = String(decoding: try JSONEncoder().encode(state), as: UTF8.self)
        #expect(!json.contains("PRIVATE_SOURCE_SENTENCE"))
        let checkpoint = try #require(state.continuity?.checkpoints.first { $0.id == id })
        #expect(checkpoint.removedSourceCount == 1)
        #expect(checkpoint.facts.count == 1); #expect(checkpoint.conflicts.isEmpty)
        #expect(ContinuityComparator.compare(checkpoint, to: state).omittedDeletedSourceCount == 1)
    }
    @Test func deletingOneOfTwoSupportingSourcesDoesNotCreateNewSurvivingLoop() throws {
        var state = CareState(); let first = try add("CBC initially ordered", kind: .labTest, action: .ordered, into: &state)
        _ = try add("CBC ordered again in saved note", kind: .labTest, action: .ordered, into: &state)
        _ = try ContinuityEngine.saveCheckpoint(title: "Before deletion", in: &state)
        Reconciler.deleteSource(first.sourceID, from: &state)
        let checkpoint = try #require(state.continuity?.checkpoints.first)
        #expect(!checkpoint.redactedDerivedIDs.isEmpty)
        #expect(!ContinuityComparator.compare(checkpoint, to: state).differences.contains { $0.kind == .loopOpened })
        try CareArchive(state: state, files: [:]).validate()
    }
    @Test func workspaceAndQuestionOnlyDebriefWorkFromEmptyState() throws {
        var state = CareState(); let id = try ContinuityEngine.createWorkspace(title: "First visit", in: &state)
        var draft = VisitDebriefDraft(); draft.questions = "What records should I bring?\nWhat records should I bring?"
        let sourceID = try ContinuityEngine.saveDebrief(draft, workspaceID: id, in: &state)
        #expect(sourceID == nil); #expect(state.sources.isEmpty); #expect(state.claims.isEmpty)
        #expect(state.questions.count == 1); #expect(state.questions[0].sourceID == nil)
        #expect(state.continuity?.workspaces[0].progress == .remembering)
        try CareArchive(state: state, files: [:]).validate()
    }
    @Test func debriefPreservesExactPatientEvidenceAndDoesNotExtractQuestions() throws {
        var state = CareState(); let id = try ContinuityEngine.createWorkspace(title: "Visit", in: &state)
        var draft = VisitDebriefDraft(); draft.heard = "Allergy: latex"; draft.nextSteps = "Call to ask about records"; draft.questions = "Should I stop metoprolol?"
        let sourceID = try #require(ContinuityEngine.saveDebrief(draft, workspaceID: id, in: &state))
        let source = try #require(state.source(sourceID))
        #expect(source.originalText.contains(draft.heard)); #expect(source.originalText.contains(draft.nextSteps))
        #expect(!source.originalText.contains(draft.questions)); #expect(source.kind == .typed && source.eventAt == nil)
        #expect(source.workingText == draft.heard + "\n\n" + draft.nextSteps)
        let proposals = try LocalExtractor.proposals(source)
        #expect(proposals.contains { $0.kind == .allergy && $0.label == "latex" })
        #expect(!proposals.contains { $0.label.contains("My after-visit recollection") || $0.label.contains("What I heard:") })
        #expect(state.claims.isEmpty && state.loops.isEmpty && state.conflicts.isEmpty)
        #expect(source.state == .pending); #expect(state.questions.first?.text == draft.questions)
        #expect(state.continuity?.workspaces[0].debrief.isEmpty == true)
        let again = try ContinuityEngine.saveDebrief(draft, workspaceID: id, in: &state)
        #expect(again == sourceID); #expect(state.sources.count == 1 && state.questions.count == 1)
    }
    @Test func lateDebriefValidationFailureIsAtomic() throws {
        var state = CareState(); let id = try ContinuityEngine.createWorkspace(title: "Visit", in: &state)
        var draft = VisitDebriefDraft(); draft.heard = "Original recollection"; draft.questions = String(repeating: "x", count: 2001)
        let before = state
        #expect(throws: CareError.self) { try ContinuityEngine.saveDebrief(draft, workspaceID: id, in: &state) }
        #expect(state == before)
    }
    @Test func checkpointRemovalDetachesWorkspaceAndPreservesSources() throws {
        var state = CareState(); _ = try add("Source preserved", into: &state)
        let id = try ContinuityEngine.createWorkspace(title: "Visit", in: &state)
        let checkpoint = try ContinuityEngine.saveCheckpoint(title: "Reference", in: &state)
        var workspace = try #require(state.continuity?.workspaces.first { $0.id == id }); workspace.checkpointID = checkpoint
        try ContinuityEngine.saveWorkspace(workspace, in: &state)
        ContinuityEngine.removeCheckpoint(checkpoint, from: &state)
        #expect(state.continuity?.workspaces[0].checkpointID == nil); #expect(state.sources.count == 1)
        ContinuityEngine.removeWorkspace(id, from: &state)
        #expect(state.sources.count == 1 && state.claims.count == 1)
    }
    @Test func oldJSONWithoutContinuityStillDecodes() throws {
        var old = try #require(JSONSerialization.jsonObject(with: JSONEncoder().encode(CareState())) as? [String: Any])
        old.removeValue(forKey: "continuity")
        let decoded = try JSONDecoder().decode(CareState.self, from: JSONSerialization.data(withJSONObject: old))
        #expect(decoded.continuity == nil)
        try CareArchive(state: decoded, files: [:]).validate()
    }
    @Test func encryptedArchiveRoundTripIncludesDraftAndCheckpoint() throws {
        var state = CareState(); _ = try add("Allergy: latex", kind: .allergy, into: &state)
        _ = try ContinuityEngine.saveCheckpoint(title: "Reference", in: &state)
        _ = try ContinuityEngine.createWorkspace(title: "My visit", in: &state)
        state.continuity?.workspaces[0].debrief.heard = "A private draft recollection"
        let encrypted = try ArchiveCodec.encrypt(CareArchive(state: state, files: [:]), passphrase: "a long test passphrase")
        #expect(!String(decoding: encrypted, as: UTF8.self).contains("private draft"))
        let restored = try ArchiveCodec.decrypt(encrypted, passphrase: "a long test passphrase")
        #expect(restored.state.continuity == state.continuity)
    }
    @Test func corruptSnapshotAndWorkspaceReferencesAreRejected() throws {
        var state = CareState(); _ = try add("Allergy: latex", kind: .allergy, into: &state)
        _ = try ContinuityEngine.saveCheckpoint(title: "Reference", in: &state)
        var broken = state; broken.continuity?.checkpoints[0].facts[0].claim.sourceID = UUID()
        #expect(throws: CareError.self) { try CareArchive(state: broken, files: [:]).validate() }
        _ = try ContinuityEngine.createWorkspace(title: "My visit", in: &state)
        state.continuity?.workspaces[0].checkpointID = UUID()
        #expect(throws: CareError.self) { try CareArchive(state: state, files: [:]).validate() }
    }
    @Test func retiredSourceVersionRemainsReadableUntilExplicitDeletion() throws {
        var state = CareState(); let claim = try add("Original exact wording", into: &state)
        _ = try ContinuityEngine.saveCheckpoint(title: "Reference", in: &state)
        state.sources[0].previousText.append(state.sources[0].workingText)
        state.sources[0].workingText = "Corrected working text"; state.sources[0].version = 2
        state.claims[0].review = .rejected; Reconciler.rebuild(&state)
        try CareArchive(state: state, files: [:]).validate()
        let checkpoint = try #require(state.continuity?.checkpoints.first)
        #expect(ContinuityComparator.compare(checkpoint, to: state).differences.contains { $0.kind == .reportRetired })
        Reconciler.deleteSource(claim.sourceID, from: &state)
        #expect(state.continuity?.checkpoints[0].facts.isEmpty == true)
    }
    @Test func evidenceChecklistIncludesEarlierWorkWithoutFalseCompletionOrOrders() throws {
        var state = CareState(); _ = try add("CBC ordered, date unclear", kind: .labTest, action: .ordered, into: &state)
        let future = EncounterRecord(title: "Future visit"); state.encounters.append(future)
        let another = EncounterRecord(title: "Other visit"); state.encounters.append(another)
        state.questions.append(Question(text: "Only another visit", encounterID: another.id))
        let items = VisitReadiness.items(state, encounterID: future.id)
        #expect(items.contains { $0.kind == .followThrough && $0.explanation.contains("Timing is not provided") })
        #expect(!items.contains { $0.title == "Only another visit" })
        #expect(items.contains { $0.kind == .unreviewed })
        #expect(VisitReadiness.items(CareState()).isEmpty)
    }
    @Test func dateAndStorageBoundsRejectInvalidMetadata() throws {
        var state = CareState(); _ = try ContinuityEngine.createWorkspace(title: "My visit", in: &state)
        var draft = try #require(state.continuity?.workspaces.first); draft.debrief.eventAt = Date(timeIntervalSinceReferenceDate: .infinity)
        #expect(throws: CareError.self) { try ContinuityEngine.saveWorkspace(draft, in: &state) }
        #expect(throws: CareError.self) { try ContinuityEngine.saveCheckpoint(title: String(repeating: "x", count: 201), in: &state) }
    }
}
