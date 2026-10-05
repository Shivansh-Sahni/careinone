import Foundation
import Testing
@testable import CareCore

struct EvidenceIntelligenceTests {
    private let firstDate = Date(timeIntervalSince1970: 1_700_000_000)
    private func add(_ text: String, label: String = "Metoprolol", kind: EntityKind = .medication, number: Double? = nil, into state: inout CareState) throws -> Claim {
        var source = Source(title: text, kind: .typed, text: text, contentHash: ContentHasher.hash(text))
        source.capturedAt = firstDate; state.sources.append(source)
        var claim = Claim(sourceID: source.id, kind: kind, label: label, quote: text)
        claim.action = kind == .labTest ? .ordered : .taking; claim.numericValue = number; claim.unit = number == nil ? "" : "mg"
        try Reconciler.accept([claim], into: &state, now: firstDate)
        return try #require(state.claims.first { $0.id == claim.id })
    }
    private func handoff(_ state: inout CareState, selected: Set<String>? = nil) throws -> UUID {
        var options = PacketOptions()
        options.selectedIDs = selected ?? VisitPacketBuilder.suggestedSelection(VisitPacketBuilder.items(state, now: firstDate))
        return try HandoffEngine.create(title: "Review copy", recipient: "My care team", options: options, in: &state, now: firstDate)
    }
    @Test func graphTracesEvidenceAndDependenciesWithTypedIDs() throws {
        var state = CareState(); let a = try add("First report 25 mg", number: 25, into: &state)
        let b = try add("Other report 50 mg", number: 50, into: &state)
        let graph = EvidenceGraph(state), entity = try #require(a.entityID)
        let upstream = graph.trace(from: .entity(entity), direction: .upstream)
        #expect(Set(upstream.steps.map(\.id)).isSuperset(of: [.report(a.id), .report(b.id), .source(a.sourceID), .source(b.sourceID)]))
        let downstream = graph.trace(from: .source(a.sourceID), direction: .downstream)
        #expect(downstream.steps.contains { if case .conflict = $0.id { true } else { false } })
        #expect(EvidenceNodeID.source(a.id) != .report(a.id))
        #expect(!upstream.truncated)
    }
    @Test func pendingRejectedAndOtherSubjectNeverEnterEvidenceGraph() throws {
        var state = CareState(); let accepted = try add("Medication from source", into: &state)
        var pending = accepted; pending.id = UUID(); pending.review = .pending
        var rejected = pending; rejected.id = UUID(); rejected.review = .rejected
        var family = accepted; family.id = UUID(); family.subject = .family
        state.claims += [pending, rejected, family]
        state.relations.append(Relation(from: rejected.id, to: accepted.id, kind: .supports))
        let graph = EvidenceGraph(state)
        #expect(graph.nodes[.report(accepted.id)] != nil)
        #expect([pending, rejected, family].allSatisfy { graph.nodes[.report($0.id)] == nil })
        #expect(!graph.edges.contains { $0.from == .report(rejected.id) })
    }
    @Test func traversalHandlesCyclesAndReportsTruncationDeterministically() throws {
        var state = CareState(); let a = try add("First report", into: &state), b = try add("Second report", into: &state)
        state.relations += [Relation(from: a.id, to: b.id, kind: .supports), Relation(from: b.id, to: a.id, kind: .supports)]
        let graph = EvidenceGraph(state)
        let full = graph.trace(from: .report(a.id), direction: .downstream)
        #expect(Set(full.steps.map(\.id)).count == full.steps.count)
        let bounded = graph.trace(from: .report(a.id), direction: .downstream, maximumDepth: 0, maximumNodes: 1)
        #expect(bounded.truncated && bounded.steps.count == 1)
        var shuffled = state; shuffled.sources.reverse(); shuffled.claims.reverse(); shuffled.relations.reverse()
        #expect(graph.edges.map(\.id) == EvidenceGraph(shuffled).edges.map(\.id))
        #expect(full.steps.map(\.id) == EvidenceGraph(shuffled).trace(from: .report(a.id), direction: .downstream).steps.map(\.id))
    }
    @Test func combinedOmissionShowsJointEffectsWithoutAnyMutationOrCompletion() throws {
        var state = CareState(); let a = try add("CBC ordered in note one", label: "CBC", kind: .labTest, into: &state)
        let b = try add("CBC requested in note two", label: "CBC", kind: .labTest, into: &state)
        let before = state
        let single = try SourceOmissionEngine.preview([a.sourceID], in: state)
        let combined = try SourceOmissionEngine.preview([a.sourceID, b.sourceID], in: state)
        #expect(single.careItemsWithoutReports.isEmpty)
        #expect(combined.careItemsWithoutReports.count == 1)
        #expect(combined.comparison.afterClaimCount == 0)
        #expect(!combined.comparison.differences.contains { $0.kind == .loopCompleted })
        #expect(state == before)
        #expect(throws: CareError.self) { try SourceOmissionEngine.preview([UUID()], in: state) }
        #expect(throws: CareError.self) { try SourceOmissionEngine.preview([], in: state) }
    }
    @Test func timelineKeepsUnknownMedicalDatesAndSeparatesEffectiveAndReviewDates() throws {
        var state = CareState(); let claim = try add("Dated later in app", into: &state)
        let index = try #require(state.claims.firstIndex { $0.id == claim.id })
        let sourceIndex = try #require(state.sources.firstIndex { $0.id == claim.sourceID })
        let event = firstDate.addingTimeInterval(-86400 * 40), effective = firstDate.addingTimeInterval(-86400 * 30)
        state.sources[sourceIndex].eventAt = event
        state.claims[index].effectiveAt = effective
        let entries = EvidenceTimeline.entries(state, reportsOnly: true)
        let report = try #require(entries.first)
        #expect(report.eventAt == nil) // A source's event does not fabricate a claim-specific event.
        #expect(report.date(on: .effective) == effective)
        #expect(report.date(on: .reviewed) == firstDate)
        #expect(report.daysAddedAfterEvent() == nil)
        state.claims[index].eventAt = event
        var calendar = Calendar(identifier: .gregorian); calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        #expect(EvidenceTimeline.entries(state, reportsOnly: true)[0].daysAddedAfterEvent(calendar: calendar) == 40)
        #expect(EvidenceTimeline.entries(state).count == 2)
    }
    @Test func lateArrivingEvidenceOrdersByMedicalDateWithoutChangingCaptureOrder() throws {
        var state = CareState(); let a = try add("A", into: &state), b = try add("B", into: &state)
        state.claims[state.claims.firstIndex { $0.id == a.id }!].eventAt = firstDate
        state.claims[state.claims.firstIndex { $0.id == b.id }!].eventAt = firstDate.addingTimeInterval(-86400)
        state.sources[state.sources.firstIndex { $0.id == b.sourceID }!].capturedAt = firstDate.addingTimeInterval(86400)
        #expect(EvidenceTimeline.entries(state, axis: .event, reportsOnly: true).first?.id == .report(a.id))
        #expect(EvidenceTimeline.entries(state, axis: .captured, reportsOnly: true).first?.id == .report(b.id))
    }
    @Test func selectedSnapshotExcludesUnselectedInformationAndRemainsImmutable() throws {
        var state = CareState(); let a = try add("Selected dose 25 mg", number: 25, into: &state)
        _ = try add("UNSELECTED_PRIVATE_ALLERGY", label: "latex", kind: .allergy, into: &state)
        state.profile.displayName = "PRIVATE_PROFILE_NAME"
        _ = try handoff(&state, selected: ["care:" + a.entityID!.uuidString])
        let saved = try #require(state.handoffs?.handoffs.first), text = try #require(saved.snapshotText)
        #expect(text.contains("Selected dose 25 mg"))
        #expect(!text.contains("UNSELECTED_PRIVATE_ALLERGY") && !text.contains("PRIVATE_PROFILE_NAME"))
        #expect(try HandoffEngine.changes(for: saved, in: state).isEmpty)
        _ = try add("New dose 50 mg", number: 50, into: &state)
        let changes = try HandoffEngine.changes(for: saved, in: state)
        #expect(changes.contains { $0.id.hasPrefix("report:") && $0.kind == .added })
        #expect(changes.contains { $0.id.hasPrefix("conflict:") })
        #expect(state.handoffs?.handoffs.first?.snapshotText == text)
        #expect(saved.snapshotDigest == ContentHasher.hash(text))
        #expect(state.conflicts.allSatisfy { $0.status == .unresolved })
    }
    @Test func handoffIgnoresPendingAndUnrelatedClaimsButDetectsSourceMetadataChanges() throws {
        var state = CareState(); let a = try add("Reviewed medication", into: &state)
        _ = try handoff(&state, selected: ["care:" + a.entityID!.uuidString])
        let saved = try #require(state.handoffs?.handoffs.first)
        _ = try add("Unrelated allergy", label: "latex", kind: .allergy, into: &state)
        var source = Source(title: "Pending dose", kind: .typed, text: "50 mg", contentHash: "pending")
        source.state = .needsReview; state.sources.append(source)
        var pending = Claim(sourceID: source.id, kind: .medication, label: "Metoprolol", quote: "50 mg"); pending.entityID = a.entityID; state.claims.append(pending)
        #expect(try HandoffEngine.changes(for: saved, in: state).isEmpty)
        state.sources[state.sources.firstIndex { $0.id == a.sourceID }!].title = "Corrected source title"
        #expect(try HandoffEngine.changes(for: saved, in: state).contains { $0.id == "source:" + a.sourceID.uuidString && $0.kind == .changed })
    }
    @Test func handoffWatchesOnlyExplicitlySelectedProfileFields() throws {
        var state = CareState(); state.questions.append(Question(text: "A question")); state.profile.displayName = "Original name"
        var options = PacketOptions(); options.selectedIDs = VisitPacketBuilder.suggestedSelection(VisitPacketBuilder.items(state)); options.includeName = true
        _ = try HandoffEngine.create(title: "Named packet", recipient: "", options: options, in: &state)
        let saved = try #require(state.handoffs?.handoffs.first)
        state.profile.contactPhone = "Not included"; state.profile.cloudConsent = true
        #expect(try HandoffEngine.changes(for: saved, in: state).isEmpty)
        state.profile.displayName = "Corrected name"
        #expect(try HandoffEngine.changes(for: saved, in: state).contains { $0.id == "profile:name" })
        #expect(saved.snapshotText?.contains("Original name") == true)
    }
    @Test func passageOfTimeAndRebuildDoNotFalselyChangeHandoff() throws {
        var state = CareState(); _ = try add("CBC ordered", label: "CBC", kind: .labTest, into: &state)
        _ = try handoff(&state)
        let saved = try #require(state.handoffs?.handoffs.first)
        Reconciler.rebuild(&state)
        state.sources.reverse(); state.claims.reverse()
        #expect(try HandoffEngine.changes(for: saved, in: state).isEmpty)
    }
    @Test func sourceReanalysisWithNewEntityIdentityStillInvalidatesOldHandoffContext() throws {
        var state = CareState(); let a = try add("Allergy: latex", label: "latex", kind: .allergy, into: &state)
        _ = try handoff(&state)
        let saved = try #require(state.handoffs?.handoffs.first)
        state.claims[0].review = .rejected; Reconciler.rebuild(&state)
        let retired = try HandoffEngine.context(for: saved, in: state)
        var proposal = Claim(sourceID: a.sourceID, kind: .allergy, label: "latex", quote: "Allergy: latex")
        proposal.action = .mentioned
        try Reconciler.accept([proposal], into: &state)
        #expect(state.claims.last?.entityID != a.entityID)
        let reanalyzed = try HandoffEngine.context(for: saved, in: state)
        #expect(retired.first { $0.id == "source:" + a.sourceID.uuidString }?.digest != reanalyzed.first { $0.id == "source:" + a.sourceID.uuidString }?.digest)
        #expect(try HandoffEngine.changes(for: saved, in: state).contains { $0.id == "source:" + a.sourceID.uuidString && $0.kind == .changed })
    }
    @Test func finishAndReopenNeverCloseClinicalWorkAndCanShowNewContext() throws {
        var state = CareState(); _ = try add("A 25 mg", number: 25, into: &state); _ = try add("B 50 mg", number: 50, into: &state)
        let id = try handoff(&state), beforeConflicts = state.conflicts
        try HandoffEngine.recordShared(id, in: &state, now: firstDate)
        try HandoffEngine.finish(id, in: &state, now: firstDate)
        #expect(state.conflicts == beforeConflicts)
        #expect(try HandoffEngine.changes(for: state.handoffs!.handoffs[0], in: state, sinceFinished: true).isEmpty)
        _ = try add("C 75 mg", number: 75, into: &state)
        #expect(!(try HandoffEngine.changes(for: state.handoffs!.handoffs[0], in: state, sinceFinished: true)).isEmpty)
        try HandoffEngine.reopen(id, in: &state)
        #expect(state.handoffs?.handoffs[0].finishedAt == nil && state.handoffs?.handoffs[0].sharedAt == firstDate)
    }
    @Test func emptyPatientCanTrackOneQuestionAndReplyThroughReviewGate() throws {
        var state = CareState(); state.questions.append(Question(text: "Which records should I bring?"))
        let id = try handoff(&state)
        try HandoffEngine.saveReplyDraft("Allergy: latex", eventAt: nil, handoffID: id, in: &state)
        let sourceID = try HandoffEngine.captureReply("Allergy: latex", eventAt: nil, handoffID: id, in: &state, now: firstDate)
        #expect(state.claims.isEmpty && state.conflicts.isEmpty && state.loops.isEmpty)
        #expect(state.source(sourceID)?.originalText == "Allergy: latex")
        #expect(state.source(sourceID)?.state == .pending && state.source(sourceID)?.eventAt == nil)
        #expect(state.handoffs?.handoffs[0].replyDraft.isEmpty == true)
        #expect(try HandoffEngine.captureReply("Allergy: latex", eventAt: nil, handoffID: id, in: &state) == sourceID)
        #expect(state.sources.count == 1)
        let proposals = try LocalExtractor.proposals(try #require(state.source(sourceID)))
        #expect(proposals.contains { $0.label == "latex" && $0.provenance == .patientReported })
        try Reconciler.accept(proposals, into: &state)
        #expect(state.claims.contains { $0.canonical && $0.label == "latex" })
    }
    @Test func replyValidationFailureAndStaleSelectionAreAtomic() throws {
        var state = CareState(); state.questions.append(Question(text: "One question"))
        let id = try handoff(&state), before = state
        #expect(throws: CareError.self) { try HandoffEngine.captureReply(String(repeating: "X", count: 30_001), eventAt: nil, handoffID: id, in: &state) }
        #expect(throws: CareError.self) { try handoff(&state, selected: ["question:" + UUID().uuidString]) }
        #expect(state == before)
    }
    @Test func sourceDeletionPurgesWholeOutgoingCopyAndPrunesAllFingerprints() throws {
        var state = CareState(); let claim = try add("SECRET_SOURCE_SENTENCE", into: &state)
        let id = try handoff(&state); try HandoffEngine.finish(id, in: &state)
        Reconciler.deleteSource(claim.sourceID, from: &state)
        try CareArchive(state: state, files: [:]).validate()
        let saved = try #require(state.handoffs?.handoffs.first)
        #expect(saved.snapshotText == nil && saved.redactedAt != nil)
        #expect(saved.baseline.isEmpty && saved.finishBaseline?.isEmpty == true)
        #expect(!String(decoding: try JSONEncoder().encode(state), as: UTF8.self).contains("SECRET_SOURCE_SENTENCE"))
        #expect(throws: CareError.self) { try HandoffEngine.recordShared(id, in: &state) }
    }
    @Test func replySourceDeletionAndHandoffDeletionPreserveIndependentEvidence() throws {
        var state = CareState(); state.questions.append(Question(text: "Bring what?")); let id = try handoff(&state)
        let replyID = try HandoffEngine.captureReply("Allergy: latex", eventAt: nil, handoffID: id, in: &state)
        Reconciler.deleteSource(replyID, from: &state)
        #expect(state.handoffs?.handoffs[0].replySourceIDs.isEmpty == true)
        #expect(state.handoffs?.handoffs[0].snapshotText != nil)
        let second = try HandoffEngine.captureReply("Second independent reply", eventAt: nil, handoffID: id, in: &state)
        HandoffEngine.remove(id, from: &state)
        #expect(state.source(second) != nil)
    }
    @Test func legacyDecodeAndEncryptedArchiveIncludeHandoffDraftAndDetectTampering() throws {
        var state = CareState(); state.questions.append(Question(text: "Question")); let id = try handoff(&state)
        try HandoffEngine.saveReplyDraft("PRIVATE_HANDOFF_DRAFT", eventAt: firstDate, handoffID: id, in: &state)
        let encrypted = try ArchiveCodec.encrypt(CareArchive(state: state, files: [:]), passphrase: "handoff archive passphrase")
        #expect(!String(decoding: encrypted, as: UTF8.self).contains("PRIVATE_HANDOFF_DRAFT"))
        #expect(try ArchiveCodec.decrypt(encrypted, passphrase: "handoff archive passphrase").state.handoffs == state.handoffs)
        var broken = state; broken.handoffs?.handoffs[0].snapshotText = "Tampered copy"
        #expect(throws: CareError.self) { try CareArchive(state: broken, files: [:]).validate() }
        broken = state; broken.handoffs?.handoffs[0].includedSourceIDs = [UUID()]
        #expect(throws: CareError.self) { try HandoffEngine.validate(broken) }
        var json = try #require(JSONSerialization.jsonObject(with: JSONEncoder().encode(state)) as? [String: Any]); json.removeValue(forKey: "handoffs")
        #expect(try JSONDecoder().decode(CareState.self, from: JSONSerialization.data(withJSONObject: json)).handoffs == nil)
    }
    @Test func handoffKeepsEncounterAfterLastSourceIsDeletedAndCanDetachExplicitly() throws {
        var state = CareState(); let claim = try add("Source with encounter", into: &state)
        let encounter = EncounterRecord(title: "Visit"); state.encounters.append(encounter)
        state.sources[0].encounterID = encounter.id
        var options = PacketOptions(); options.encounterID = encounter.id; options.selectedIDs = VisitPacketBuilder.suggestedSelection(VisitPacketBuilder.items(state))
        _ = try HandoffEngine.create(title: "Visit handoff", recipient: "", options: options, in: &state)
        Reconciler.deleteSource(claim.sourceID, from: &state)
        #expect(state.encounters.contains { $0.id == encounter.id })
        HandoffEngine.detachEncounter(encounter.id, in: &state); state.encounters.removeAll()
        try HandoffEngine.validate(state)
        #expect(state.handoffs?.handoffs.first?.encounterID == nil)
    }
}
