import Foundation
import Testing
@testable import CareCore

struct FollowThroughAssistTests {
    private func fixture(encounter: Bool = false) throws -> (CareState, CareLoop) {
        var state = CareState()
        var source = Source(title: "Visit instructions", kind: .typed, text: "CBC ordered. Please contact the lab to arrange it.", contentHash: "source")
        if encounter { let visit = EncounterRecord(title: "A visit"); state.encounters.append(visit); source.encounterID = visit.id }
        state.sources.append(source)
        var claim = Claim(sourceID: source.id, kind: .labTest, label: "CBC", quote: source.workingText)
        claim.action = .ordered
        try Reconciler.accept([claim], into: &state)
        return (state, try #require(state.loops.first))
    }
    @Test func firstPlanIsUsefulWithoutDatesProviderOrCompleteChart() throws {
        var (state, loop) = try fixture()
        let originalClaims = state.claims, originalLoops = state.loops
        let id = try FollowThroughAssistEngine.create(loopID: loop.id, in: &state)
        let plan = try #require(FollowThroughAssistEngine.plan(for: loop.id, in: state))
        #expect(plan.id == id && plan.checkBackAt == nil && plan.replyEventAt == nil)
        #expect(plan.messageDraft.contains(state.sources[0].workingText))
        #expect(plan.messageDraft.contains("event date not saved"))
        #expect(!plan.messageDraft.contains("overdue"))
        #expect(state.claims == originalClaims && state.loops == originalLoops)
        #expect(try FollowThroughAssistEngine.create(loopID: loop.id, in: &state) == id)
        #expect(state.followThroughPlans?.plans.count == 1)
    }
    @Test func outreachHistoryAndPersonalDateDoNotAdvanceClinicalState() throws {
        var (state, loop) = try fixture()
        let id = try FollowThroughAssistEngine.create(loopID: loop.id, in: &state)
        var plan = try #require(FollowThroughAssistEngine.plan(for: loop.id, in: state))
        plan.checkBackAt = Date(timeIntervalSince1970: 2_000_000_000); plan.attemptDraft = "Left a message"
        try FollowThroughAssistEngine.save(plan, in: &state)
        for kind in [FollowThroughAttemptKind.contacted, .waiting, .paperworkReady] { try FollowThroughAssistEngine.recordAttempt(planID: id, kind: kind, note: "My own note", in: &state) }
        #expect(state.loops[0] == loop)
        #expect(state.loops[0].dueAt == nil)
        #expect(state.followThroughPlans?.plans[0].history.count == 3)
        #expect(state.followThroughPlans?.plans[0].attemptDraft == "")
        #expect(throws: CareError.self) { try FollowThroughAssistEngine.recordAttempt(planID: id, kind: .replySaved, in: &state) }
    }
    @Test func replyPreservesPatientTextWithoutExtractingGeneratedMessage() throws {
        var (state, loop) = try fixture(encounter: true)
        let id = try FollowThroughAssistEngine.create(loopID: loop.id, in: &state)
        let before = state.claims
        let text = "The office said: CBC scheduled for October 2."
        let sourceID = try FollowThroughAssistEngine.captureReply(text, eventAt: nil, planID: id, synthetic: true, in: &state)
        let source = try #require(state.source(sourceID))
        #expect(source.originalText == text && source.workingText == text)
        #expect(source.kind == .typed && source.state == .pending && source.synthetic)
        #expect(source.eventAt == nil && source.encounterID == loop.encounterID)
        #expect(state.claims == before && state.loops[0] == loop)
        #expect(!source.workingText.contains("Could you confirm"))
        #expect(state.followThroughPlans?.plans[0].history.last?.kind == .replySaved)
        #expect(state.followThroughPlans?.plans[0].replySourceIDs == [sourceID])
    }
    @Test func sameReplyIsIdempotentButEditedSourceIsNotReused() throws {
        var (state, loop) = try fixture()
        let id = try FollowThroughAssistEngine.create(loopID: loop.id, in: &state)
        let first = try FollowThroughAssistEngine.captureReply("Office called back", eventAt: nil, planID: id, synthetic: false, in: &state)
        #expect(try FollowThroughAssistEngine.captureReply("Office called back", eventAt: nil, planID: id, synthetic: false, in: &state) == first)
        #expect(state.followThroughPlans?.plans[0].history.count == 1)
        let sourceIndex = try #require(state.sources.firstIndex { $0.id == first })
        state.sources[sourceIndex].workingText = "Corrected recollection"
        let second = try FollowThroughAssistEngine.captureReply("Office called back", eventAt: nil, planID: id, synthetic: false, in: &state)
        #expect(second != first)
    }
    @Test func invalidReplyAndOversizedDraftRollbackCompletely() throws {
        var (state, loop) = try fixture()
        let id = try FollowThroughAssistEngine.create(loopID: loop.id, in: &state)
        let before = state
        #expect(throws: CareError.self) { try FollowThroughAssistEngine.captureReply("  \n", eventAt: nil, planID: id, synthetic: false, in: &state) }
        #expect(state == before)
        #expect(throws: CareError.self) { try FollowThroughAssistEngine.captureReply("A reply", eventAt: Date(timeIntervalSince1970: .nan), planID: id, synthetic: false, in: &state) }
        #expect(state == before)
        var plan = try #require(state.followThroughPlans?.plans.first)
        plan.messageDraft = String(repeating: "x", count: FollowThroughAssistEngine.maximumDraftCharacters + 1)
        #expect(throws: CareError.self) { try FollowThroughAssistEngine.save(plan, in: &state) }
        #expect(state == before)
    }
    @Test func checkBackRequiresBothConsentSettingsAndAnOpenTask() throws {
        var (state, loop) = try fixture()
        _ = try FollowThroughAssistEngine.create(loopID: loop.id, in: &state)
        let now = Date(timeIntervalSince1970: 1000), future = Date(timeIntervalSince1970: 2000)
        state.followThroughPlans?.plans[0].checkBackAt = future
        #expect(FollowThroughAssistEngine.checkBacks(in: state, now: now).isEmpty)
        state.profile.notifications = true; state.profile.notifyTasks = false
        #expect(FollowThroughAssistEngine.checkBacks(in: state, now: now).isEmpty)
        state.profile.notifyTasks = true
        #expect(FollowThroughAssistEngine.checkBacks(in: state, now: now).first?.date == future)
        #expect(FollowThroughAssistEngine.checkBacks(in: state, now: future).isEmpty)
        state.loops[0].status = .completed
        #expect(FollowThroughAssistEngine.checkBacks(in: state, now: now).isEmpty)
        state.loops[0].status = .uncertain
        #expect(FollowThroughAssistEngine.checkBacks(in: state, now: now).count == 1)
    }
    @Test func deletingSupportingEvidencePurgesCopiedDraftsAndNotes() throws {
        var (state, loop) = try fixture()
        let id = try FollowThroughAssistEngine.create(loopID: loop.id, in: &state)
        var plan = try #require(state.followThroughPlans?.plans.first)
        plan.messageDraft = "COPY_SECRET"; plan.replyDraft = "DRAFT_SECRET"; plan.attemptDraft = "NOTE_SECRET"
        try FollowThroughAssistEngine.save(plan, in: &state)
        try FollowThroughAssistEngine.recordAttempt(planID: id, kind: .contacted, note: "HISTORY_SECRET", in: &state)
        FollowThroughAssistEngine.removeSource(state.sources[0].id, from: &state)
        #expect(state.followThroughPlans?.plans.isEmpty == true)
        let json = String(decoding: try JSONEncoder().encode(state), as: UTF8.self)
        #expect(!json.contains("SECRET"))
    }
    @Test func deletingReplyRemovesItsPlanButNotIndependentClinicalEvidence() throws {
        var (state, loop) = try fixture()
        let id = try FollowThroughAssistEngine.create(loopID: loop.id, in: &state)
        let reply = try FollowThroughAssistEngine.captureReply("An actual reply", eventAt: nil, planID: id, synthetic: false, in: &state)
        FollowThroughAssistEngine.removeSource(reply, from: &state)
        #expect(state.followThroughPlans?.plans.isEmpty == true)
        #expect(state.claims.count == 1 && state.loops[0] == loop)
    }
    @Test func sourceChangesFlagDraftAndRefreshExplicitlyUsesNewEvidence() throws {
        var (state, loop) = try fixture()
        let id = try FollowThroughAssistEngine.create(loopID: loop.id, in: &state)
        let old = try #require(state.followThroughPlans?.plans.first)
        #expect(!FollowThroughAssistEngine.savedInformationChanged(old, in: state))
        state.sources[0].title = "Corrected source title"
        #expect(FollowThroughAssistEngine.savedInformationChanged(old, in: state))
        #expect(state.followThroughPlans?.plans[0].messageDraft == old.messageDraft)
        try FollowThroughAssistEngine.refreshMessage(id, in: &state)
        let updated = try #require(state.followThroughPlans?.plans.first)
        #expect(updated.messageDraft.contains("Corrected source title"))
        #expect(!FollowThroughAssistEngine.savedInformationChanged(updated, in: state))
    }
    @Test func draftEditsCannotForgeLineageOrOutreachHistory() throws {
        var (state, loop) = try fixture()
        _ = try FollowThroughAssistEngine.create(loopID: loop.id, in: &state)
        let before = state
        var plan = try #require(state.followThroughPlans?.plans.first)
        plan.supportingSourceIDs = []
        #expect(throws: CareError.self) { try FollowThroughAssistEngine.save(plan, in: &state) }
        plan = try #require(state.followThroughPlans?.plans.first)
        plan.history.append(FollowThroughAttempt(kind: .contacted, date: Date(), note: "Forged"))
        #expect(throws: CareError.self) { try FollowThroughAssistEngine.save(plan, in: &state) }
        #expect(state == before)
    }
    @Test func unknownVersionMissingSourcesAndOversizedHistoryAreRejected() throws {
        var (state, loop) = try fixture()
        let id = try FollowThroughAssistEngine.create(loopID: loop.id, in: &state)
        var bad = state; bad.followThroughPlans?.version = 2
        #expect(throws: CareError.self) { try FollowThroughAssistEngine.validate(bad) }
        bad = state; bad.followThroughPlans?.plans[0].supportingSourceIDs = [UUID()]
        #expect(throws: CareError.self) { try FollowThroughAssistEngine.validate(bad) }
        state.followThroughPlans?.plans[0].history = (0..<FollowThroughAssistEngine.maximumHistory).map { _ in FollowThroughAttempt(kind: .waiting, date: Date(), note: "") }
        let before = state
        #expect(throws: CareError.self) { try FollowThroughAssistEngine.recordAttempt(planID: id, kind: .waiting, in: &state) }
        #expect(state == before)
    }
    @Test func planSurvivesRoundtripAndEncounterRemovalWithoutInventingDates() throws {
        var (state, loop) = try fixture(encounter: true)
        _ = try FollowThroughAssistEngine.create(loopID: loop.id, in: &state)
        let decoded = try JSONDecoder().decode(CareState.self, from: JSONEncoder().encode(state))
        #expect(decoded == state)
        FollowThroughAssistEngine.detachEncounter(try #require(loop.encounterID), from: &state)
        #expect(state.followThroughPlans?.plans[0].encounterID == nil)
        #expect(state.followThroughPlans?.plans[0].checkBackAt == nil)
        state.loops.removeAll(); FollowThroughAssistEngine.pruneUnavailableLoops(in: &state)
        #expect(state.followThroughPlans?.plans.count == 1)
        try FollowThroughAssistEngine.validate(state)
    }
    @Test func existingScheduledAndCompletedStagesUseRelevantWordsWithoutMedicalAdvice() throws {
        var (state, loop) = try fixture()
        state.loops[0].stage = .scheduled
        let scheduled = try FollowThroughAssistEngine.message(for: loop.id, obstacle: .schedule, in: state)
        #expect(scheduled.contains("confirm the arrangements"))
        state.loops[0].stage = .completed
        let completed = try FollowThroughAssistEngine.message(for: loop.id, obstacle: .schedule, in: state)
        #expect(completed.contains("find the result"))
        let paperwork = try FollowThroughAssistEngine.message(for: loop.id, obstacle: .paperwork, in: state)
        #expect(paperwork.contains("Which records, forms, or authorization"))
        #expect(!paperwork.contains("stop taking"))
    }
    @Test func createValidatesBeforePublishingOversizedGeneratedContent() throws {
        var (state, loop) = try fixture()
        state.sources[0].title = String(repeating: "x", count: FollowThroughAssistEngine.maximumDraftCharacters + 1)
        let before = state
        #expect(throws: CareError.self) { try FollowThroughAssistEngine.create(loopID: loop.id, in: &state) }
        #expect(state == before)
    }
    @Test func aggregateDraftLimitPreventsAnOversizedArchive() throws {
        var (state, loop) = try fixture()
        _ = try FollowThroughAssistEngine.create(loopID: loop.id, in: &state)
        let template = try #require(state.followThroughPlans?.plans.first)
        state.followThroughPlans?.plans = []
        for index in 0..<101 {
            var anotherLoop = loop; anotherLoop.id = loop.id + "-" + String(index)
            state.loops.append(anotherLoop)
            var plan = template; plan.id = UUID(); plan.loopID = anotherLoop.id
            plan.messageDraft = String(repeating: "x", count: FollowThroughAssistEngine.maximumDraftCharacters)
            state.followThroughPlans?.plans.append(plan)
        }
        #expect(throws: CareError.self) { try FollowThroughAssistEngine.validate(state) }
    }
    @Test func replyCannotPublishNewSourceWhenHistoryIsFull() throws {
        var (state, loop) = try fixture()
        let id = try FollowThroughAssistEngine.create(loopID: loop.id, in: &state)
        state.followThroughPlans?.plans[0].history = (0..<FollowThroughAssistEngine.maximumHistory).map { _ in FollowThroughAttempt(kind: .waiting, date: Date(), note: "") }
        let before = state
        #expect(throws: CareError.self) { try FollowThroughAssistEngine.captureReply("A reply", eventAt: nil, planID: id, synthetic: false, in: &state) }
        #expect(state == before)
    }
    @Test func removedOrReplacedPlanCannotBeRecoveredFromStaleViewDraft() throws {
        var (state, loop) = try fixture()
        _ = try FollowThroughAssistEngine.create(loopID: loop.id, in: &state)
        var draft = try #require(state.followThroughPlans?.plans.first)
        let baseline = draft; draft.messageDraft = "PRIVATE_COPIED_EVIDENCE"; draft.replyDraft = "PRIVATE_REPLY"
        FollowThroughAssistEngine.removeSource(state.sources[0].id, from: &state)
        #expect(FollowThroughAssistEngine.rebaseEditableDraft(draft, baseline: baseline, onto: FollowThroughAssistEngine.plan(for: loop.id, in: state)) == nil)
        _ = try FollowThroughAssistEngine.create(loopID: loop.id, in: &state)
        #expect(FollowThroughAssistEngine.rebaseEditableDraft(draft, baseline: baseline, onto: FollowThroughAssistEngine.plan(for: loop.id, in: state)) == nil)
    }
    @Test func rebaseKeepsOnlyUserEditsAndTakesLiveHistoryAndMetadata() throws {
        var (state, loop) = try fixture()
        let id = try FollowThroughAssistEngine.create(loopID: loop.id, in: &state)
        let baseline = try #require(state.followThroughPlans?.plans.first)
        var draft = baseline; draft.replyDraft = "My unfinished reply"
        try FollowThroughAssistEngine.recordAttempt(planID: id, kind: .contacted, note: "Saved elsewhere", in: &state)
        state.followThroughPlans?.plans[0].recipient = "Updated office"
        let stored = try #require(state.followThroughPlans?.plans.first)
        let recovered = try #require(FollowThroughAssistEngine.rebaseEditableDraft(draft, baseline: baseline, onto: stored))
        #expect(recovered.replyDraft == draft.replyDraft)
        #expect(recovered.recipient == stored.recipient)
        #expect(recovered.history == stored.history && recovered.supportingSourceIDs == stored.supportingSourceIDs)
        try FollowThroughAssistEngine.save(recovered, in: &state)
    }
    @Test func sourceEditPausesPlanAndExplicitRelinkPreservesPatientWork() throws {
        var (state, loop) = try fixture()
        let id = try FollowThroughAssistEngine.create(loopID: loop.id, in: &state)
        var plan = try #require(state.followThroughPlans?.plans.first)
        plan.replyDraft = "Actual reply not saved yet"; plan.messageDraft = "My own call script"
        try FollowThroughAssistEngine.save(plan, in: &state)
        try FollowThroughAssistEngine.recordAttempt(planID: id, kind: .contacted, note: "I called once", in: &state)
        state.sources[0].workingText = "CBC requested by the office."
        for i in state.claims.indices { state.claims[i].review = .rejected }
        Reconciler.rebuild(&state)
        #expect(state.loops.isEmpty)
        let paused = try #require(state.followThroughPlans?.plans.first)
        #expect(paused.replyDraft == plan.replyDraft && paused.history.count == 1)
        try FollowThroughAssistEngine.validate(state)
        let reply = try FollowThroughAssistEngine.captureReply("Office said they will call", eventAt: nil, planID: id, synthetic: false, in: &state)
        #expect(state.source(reply)?.state == .pending)
        var accepted = Claim(sourceID: state.sources[0].id, kind: .labTest, label: "CBC", quote: state.sources[0].workingText); accepted.action = .requested
        try Reconciler.accept([accepted], into: &state)
        let target = try #require(state.loops.first)
        #expect(target.id != loop.id)
        let before = try #require(state.followThroughPlans?.plans.first)
        try FollowThroughAssistEngine.relink(id, toLoopID: target.id, in: &state)
        let linked = try #require(state.followThroughPlans?.plans.first)
        #expect(linked.loopID == target.id && linked.messageDraft == before.messageDraft)
        #expect(linked.history == before.history && linked.replySourceIDs == before.replySourceIDs)
        #expect(FollowThroughAssistEngine.savedInformationChanged(linked, in: state))
        try FollowThroughAssistEngine.validate(state)
    }
    @Test func reconnectingDoesNotSilentlyMergeTwoPatientPlans() throws {
        var (state, loop) = try fixture()
        let id = try FollowThroughAssistEngine.create(loopID: loop.id, in: &state)
        var secondLoop = loop; secondLoop.id += "-second"; state.loops.append(secondLoop)
        _ = try FollowThroughAssistEngine.create(loopID: secondLoop.id, in: &state)
        let before = state
        #expect(throws: CareError.self) { try FollowThroughAssistEngine.relink(id, toLoopID: secondLoop.id, in: &state) }
        #expect(state == before)
    }
}
