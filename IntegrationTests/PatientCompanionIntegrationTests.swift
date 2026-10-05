import XCTest
import SwiftData
import CareCore
@testable import CareContinuity

@MainActor final class PatientCompanionIntegrationTests: XCTestCase {
    func testPatientCompanionDraftsAndVisitPositionSurviveSQLiteRelaunch() throws {
        let vault = try makeVault()
        let cleanupRoot1 = vault.root; addTeardownBlock { try? FileManager.default.removeItem(at: cleanupRoot1) }
        let store = try AppStore(repository: SwiftDataRepository(root: vault.root), vault: vault, systemServicesEnabled: false)
        let fixture = try populateCompanions(in: store)
        var secondQuestionID: UUID?
        XCTAssertTrue(store.mutate { state in
            try VisitCompanionEngine.addQuestion("Who should I contact afterwards?", companionID: fixture.companionID, in: &state)
            secondQuestionID = state.visitCompanions?.sessions.first?.questions.last?.id
            try VisitCompanionEngine.setPosition(try XCTUnwrap(secondQuestionID), companionID: fixture.companionID, in: &state)
            try VisitCompanionEngine.markQuestion(.later, questionID: try XCTUnwrap(secondQuestionID), companionID: fixture.companionID, in: &state)
        })
        let before = store.state

        let reopened = try AppStore(repository: SwiftDataRepository(root: vault.root), vault: vault, systemServicesEnabled: false)
        XCTAssertEqual(reopened.state.visitCompanions, before.visitCompanions)
        XCTAssertEqual(reopened.state.followThroughPlans, before.followThroughPlans)
        let session = try XCTUnwrap(reopened.state.visitCompanions?.sessions.first)
        XCTAssertEqual(session.currentQuestionID, secondQuestionID)
        XCTAssertEqual(session.progress, .inVisit)
        XCTAssertEqual(session.questions.first?.answer, "Allergy: latex")
        XCTAssertEqual(session.questions.last?.progress, .later)
        let plan = try XCTUnwrap(reopened.state.followThroughPlans?.plans.first)
        XCTAssertEqual(plan.replyDraft, "Allergy: penicillin")
        XCTAssertEqual(plan.history.map(\.kind), [.contacted])
        XCTAssertNotNil(plan.checkBackAt)
        XCTAssertNil(reopened.state.loops.first?.dueAt, "A personal check-back must not become a clinical due date.")
        XCTAssertEqual(reopened.state.claims.filter(\.canonical).count, 1)
    }

    func testEncryptedRestorePreservesPatientCompanionDraftsButResetsConsent() throws {
        let vault = try makeVault()
        let cleanupRoot2 = vault.root; addTeardownBlock { try? FileManager.default.removeItem(at: cleanupRoot2) }
        let store = try AppStore(repository: SwiftDataRepository(root: vault.root), vault: vault, systemServicesEnabled: false)
        _ = try populateCompanions(in: store)
        XCTAssertTrue(store.mutate {
            $0.profile.cloudConsent = true
            $0.profile.cloudConsentAt = Date(timeIntervalSince1970: 1_800_000_000)
            $0.profile.cloudProviderConfigurationID = "synthetic-provider-consent"
            $0.profile.notifications = true
        })
        let before = store.state
        let passphrase = "patient companion integration archive"
        let encrypted = try ArchiveCodec.encrypt(store.archive(includeAudio: true), passphrase: passphrase)
        XCTAssertFalse(String(decoding: encrypted, as: UTF8.self).contains("Allergy: latex"))
        XCTAssertTrue(store.mutate { $0 = CareState() })
        XCTAssertNil(store.state.visitCompanions)
        XCTAssertNil(store.state.followThroughPlans)

        try store.restore(ArchiveCodec.decrypt(encrypted, passphrase: passphrase))
        XCTAssertEqual(store.state.visitCompanions, before.visitCompanions)
        XCTAssertEqual(store.state.followThroughPlans, before.followThroughPlans)
        XCTAssertFalse(store.state.profile.cloudConsent)
        XCTAssertNil(store.state.profile.cloudConsentAt)
        XCTAssertNil(store.state.profile.cloudProviderConfigurationID)
        XCTAssertFalse(store.state.profile.notifications)
        let reopened = try AppStore(repository: SwiftDataRepository(root: vault.root), vault: vault, systemServicesEnabled: false)
        XCTAssertEqual(reopened.state.visitCompanions, before.visitCompanions)
        XCTAssertEqual(reopened.state.followThroughPlans, before.followThroughPlans)
    }

    func testLegacyPreferencesWithoutPatientCompanionsKeepExistingCare() throws {
        let vault = try makeVault()
        let cleanupRoot3 = vault.root; addTeardownBlock { try? FileManager.default.removeItem(at: cleanupRoot3) }
        let repository = try SwiftDataRepository(root: vault.root)
        var state = CareState()
        try SyntheticDemo.load(into: &state)
        try repository.save(state)

        let record = try XCTUnwrap(repository.context.fetch(FetchDescriptor<PatientProfile>()).first)
        var payload = try XCTUnwrap(JSONSerialization.jsonObject(with: record.payload) as? [String: Any])
        payload.removeValue(forKey: "visitCompanions")
        payload.removeValue(forKey: "followThroughPlans")
        record.payload = try JSONSerialization.data(withJSONObject: payload)
        try repository.context.save()

        let reopened = try AppStore(repository: SwiftDataRepository(root: vault.root), vault: vault, systemServicesEnabled: false)
        XCTAssertNil(reopened.state.visitCompanions)
        XCTAssertNil(reopened.state.followThroughPlans)
        XCTAssertEqual(Set(reopened.state.sources.map(\.id)), Set(state.sources.map(\.id)))
        XCTAssertEqual(Set(reopened.state.claims.filter(\.canonical).map(\.id)), Set(state.claims.filter(\.canonical).map(\.id)))
        XCTAssertEqual(reopened.state.profile, state.profile)
    }

    func testFailedVisitAnswerCaptureRetainsDraftAndPreviouslySavedCare() throws {
        let vault = try makeVault()
        let cleanupRoot4 = vault.root; addTeardownBlock { try? FileManager.default.removeItem(at: cleanupRoot4) }
        let repository = CompanionFailingRepository()
        let store = try AppStore(repository: repository, vault: vault, systemServicesEnabled: false)
        let fixture = try populateCompanions(in: store)
        let before = store.state
        repository.fail = true

        XCTAssertNil(store.captureVisitCompanionAnswers(fixture.companionID))
        XCTAssertEqual(store.state, before)
        XCTAssertEqual(repository.value, before)
        XCTAssertEqual(store.state.visitCompanions?.sessions.first?.questions.first?.answer, "Allergy: latex")
        XCTAssertEqual(store.state.sources.count, 1)
        XCTAssertEqual(store.state.claims.filter(\.canonical).count, 1)
        XCTAssertNil(store.createVisitCompanion(title: "Could not save"))
        XCTAssertEqual(store.state, before)
    }

    func testFailedFollowThroughReplyCaptureRetainsDraftAndOutreachHistory() throws {
        let vault = try makeVault()
        let cleanupRoot5 = vault.root; addTeardownBlock { try? FileManager.default.removeItem(at: cleanupRoot5) }
        let repository = CompanionFailingRepository()
        let store = try AppStore(repository: repository, vault: vault, systemServicesEnabled: false)
        let fixture = try populateCompanions(in: store)
        let before = store.state
        repository.fail = true

        XCTAssertNil(store.captureFollowThroughReply("Allergy: penicillin", eventAt: nil, planID: fixture.planID, synthetic: false))
        XCTAssertEqual(store.state, before)
        XCTAssertEqual(repository.value, before)
        XCTAssertEqual(store.state.followThroughPlans?.plans.first?.replyDraft, "Allergy: penicillin")
        XCTAssertEqual(store.state.followThroughPlans?.plans.first?.history.map(\.kind), [.contacted])
        XCTAssertEqual(store.state.sources.count, 1)
        XCTAssertEqual(store.state.loops.first?.status, .open)
    }

    func testSavedCompanionAnswersAndRepliesRequireNormalReviewBeforeChangingCare() throws {
        let vault = try makeVault()
        let cleanupRoot6 = vault.root; addTeardownBlock { try? FileManager.default.removeItem(at: cleanupRoot6) }
        let store = try AppStore(repository: SwiftDataRepository(root: vault.root), vault: vault, systemServicesEnabled: false)
        let fixture = try populateCompanions(in: store)
        let before = store.state.claims.filter(\.canonical)
        var answerID: UUID?
        var replyID: UUID?
        XCTAssertTrue(store.mutate {
            answerID = try VisitCompanionEngine.captureAnswers(companionID: fixture.companionID, in: &$0)
            replyID = try FollowThroughAssistEngine.captureReply("Allergy: penicillin", eventAt: nil, planID: fixture.planID, synthetic: false, in: &$0)
        })
        let answers = try XCTUnwrap(store.source(try XCTUnwrap(answerID)))
        let reply = try XCTUnwrap(store.source(try XCTUnwrap(replyID)))
        XCTAssertEqual(answers.workingText, "Allergy: latex")
        XCTAssertEqual(reply.workingText, "Allergy: penicillin")
        XCTAssertEqual(answers.state, .pending)
        XCTAssertEqual(reply.state, .pending)
        XCTAssertFalse(answers.originalText.contains("PRIVATE_AGENDA_COPY"))
        XCTAssertEqual(store.state.claims.filter(\.canonical), before)
        XCTAssertEqual(store.state.loops.first?.status, .open)
        let proposals = try LocalExtractor.proposals(answers) + LocalExtractor.proposals(reply)
        XCTAssertEqual(Set(proposals.map(\.label)), ["latex", "penicillin"])
        XCTAssertTrue(proposals.allSatisfy { $0.provenance == .patientReported && $0.review == .pending })
        XCTAssertTrue(store.accept(proposals))
        XCTAssertEqual(store.state.claims.filter(\.canonical).count, before.count + 2)
        XCTAssertEqual(store.state.loops.first?.status, .open)
        let reopened = try AppStore(repository: SwiftDataRepository(root: vault.root), vault: vault, systemServicesEnabled: false)
        XCTAssertEqual(reopened.state.visitCompanions?.sessions.first?.capturedSourceIDs, [answers.id])
        XCTAssertEqual(reopened.state.followThroughPlans?.plans.first?.replySourceIDs, [reply.id])
        XCTAssertEqual(reopened.state.claims.filter(\.canonical).count, before.count + 2)
    }

    func testSourceDeletionScrubsCopiedCompanionContentOnlyAfterCommitAndPreservesReplyEvidence() throws {
        let vault = try makeVault()
        let cleanupRoot7 = vault.root; addTeardownBlock { try? FileManager.default.removeItem(at: cleanupRoot7) }
        let repository = CompanionFailingRepository()
        let store = try AppStore(repository: repository, vault: vault, systemServicesEnabled: false)
        let fixture = try populateCompanions(in: store)
        var replyID: UUID?
        XCTAssertTrue(store.mutate {
            replyID = try FollowThroughAssistEngine.captureReply("A separately saved patient reply", eventAt: nil, planID: fixture.planID, synthetic: false, in: &$0)
        })
        let before = store.state
        repository.fail = true
        XCTAssertFalse(store.deleteSource(fixture.sourceID))
        XCTAssertEqual(store.state, before)
        XCTAssertEqual(repository.value, before)

        repository.fail = false
        XCTAssertTrue(store.deleteSource(fixture.sourceID))
        XCTAssertTrue(store.state.followThroughPlans?.plans.isEmpty == true)
        let companion = try XCTUnwrap(store.state.visitCompanions?.sessions.first)
        XCTAssertTrue(companion.questions.isEmpty)
        XCTAssertNil(companion.currentQuestionID)
        XCTAssertEqual(companion.removedQuestionCount, 1)
        XCTAssertNotNil(store.source(try XCTUnwrap(replyID)))
        let encoded = String(decoding: try JSONEncoder().encode(store.state), as: UTF8.self)
        XCTAssertFalse(encoded.contains("PRIVATE_AGENDA_COPY"))
        XCTAssertFalse(encoded.contains("PRIVATE_PLAN_NOTE"))
        XCTAssertNoThrow(try store.archive(includeAudio: true).validate())
    }

    func testDeletingCapturedAnswerEvidenceScrubsRetainedAnswerDrafts() throws {
        let vault = try makeVault()
        let cleanupRoot8 = vault.root; addTeardownBlock { try? FileManager.default.removeItem(at: cleanupRoot8) }
        let store = try AppStore(repository: SwiftDataRepository(root: vault.root), vault: vault, systemServicesEnabled: false)
        let fixture = try populateCompanions(in: store)
        var firstID: UUID?
        XCTAssertTrue(store.mutate { firstID = try VisitCompanionEngine.captureAnswers(companionID: fixture.companionID, in: &$0) })
        var secondID: UUID?
        XCTAssertTrue(store.mutate {
            try VisitCompanionEngine.saveAnswer("A separately saved later recollection", questionID: fixture.questionID, companionID: fixture.companionID, in: &$0)
            secondID = try VisitCompanionEngine.captureAnswers(companionID: fixture.companionID, in: &$0)
        })
        XCTAssertTrue(store.deleteSource(try XCTUnwrap(firstID)))
        let session = try XCTUnwrap(store.state.visitCompanions?.sessions.first)
        XCTAssertEqual(session.capturedSourceIDs, [try XCTUnwrap(secondID)])
        XCTAssertEqual(session.lastCaptureSourceID, secondID)
        XCTAssertNotNil(session.lastCaptureDigest)
        XCTAssertEqual(session.questions.first?.answer, "")
        XCTAssertEqual(session.clearedAnswerCount, 1)
        XCTAssertFalse(store.mutate { _ = try VisitCompanionEngine.captureAnswers(companionID: fixture.companionID, in: &$0) })
        XCTAssertFalse(String(decoding: try JSONEncoder().encode(store.state.visitCompanions), as: UTF8.self).contains("Allergy: latex"))
        XCTAssertFalse(String(decoding: try JSONEncoder().encode(store.state.visitCompanions), as: UTF8.self).contains("A separately saved later recollection"))
        XCTAssertEqual(store.source(try XCTUnwrap(secondID))?.workingText, "A separately saved later recollection")
        XCTAssertEqual(store.state.claims.filter(\.canonical).count, 1)
        XCTAssertNoThrow(try store.archive(includeAudio: true).validate())
    }

    func testSourceCorrectionPausesHelperWithoutDiscardingDraftsAndCanReconnectAfterReview() throws {
        let vault = try makeVault()
        let cleanupRoot9 = vault.root; addTeardownBlock { try? FileManager.default.removeItem(at: cleanupRoot9) }
        let store = try AppStore(repository: SwiftDataRepository(root: vault.root), vault: vault, systemServicesEnabled: false)
        let fixture = try populateCompanions(in: store)
        XCTAssertTrue(store.mutate { $0.profile.notifications = true; $0.profile.notifyTasks = true })
        let savedPlan = try XCTUnwrap(store.state.followThroughPlans?.plans.first)
        XCTAssertEqual(FollowThroughAssistEngine.checkBacks(in: store.state, now: Date(timeIntervalSince1970: 1_800_000_000)).count, 1)

        let correctedDate = Date(timeIntervalSince1970: 1_790_000_000)
        XCTAssertTrue(store.editSource(fixture.sourceID, title: "Corrected test order", text: "CBC ordered. Event date corrected.", event: correctedDate, encounter: nil, provider: ""))
        XCTAssertTrue(store.state.loops.isEmpty)
        XCTAssertTrue(store.state.claims.filter(\.canonical).isEmpty)
        XCTAssertEqual(store.state.followThroughPlans?.plans.first, savedPlan)
        XCTAssertTrue(FollowThroughAssistEngine.savedInformationChanged(savedPlan, in: store.state))
        XCTAssertTrue(FollowThroughAssistEngine.checkBacks(in: store.state, now: Date(timeIntervalSince1970: 1_800_000_000)).isEmpty)
        XCTAssertNoThrow(try store.archive(includeAudio: true).validate())

        let reopened = try AppStore(repository: SwiftDataRepository(root: vault.root), vault: vault, systemServicesEnabled: false)
        XCTAssertEqual(reopened.state.followThroughPlans?.plans.first, savedPlan)
        XCTAssertTrue(reopened.state.loops.isEmpty)
        let source = try XCTUnwrap(reopened.source(fixture.sourceID))
        XCTAssertEqual(source.eventAt, correctedDate)
        XCTAssertEqual(source.previousText, ["CBC ordered"])
        var correctedClaim = Claim(sourceID: source.id, kind: .labTest, label: "CBC", quote: "CBC ordered")
        correctedClaim.action = .ordered
        correctedClaim.eventAt = correctedDate
        XCTAssertTrue(reopened.accept([correctedClaim]))
        let currentLoopID = try XCTUnwrap(reopened.state.loops.first?.id)
        XCTAssertTrue(reopened.mutate { try FollowThroughAssistEngine.relink(fixture.planID, toLoopID: currentLoopID, in: &$0) })

        let reconnected = try XCTUnwrap(reopened.state.followThroughPlans?.plans.first)
        XCTAssertEqual(reconnected.id, savedPlan.id)
        XCTAssertEqual(reconnected.loopID, currentLoopID)
        XCTAssertEqual(reconnected.messageDraft, savedPlan.messageDraft)
        XCTAssertEqual(reconnected.replyDraft, savedPlan.replyDraft)
        XCTAssertEqual(reconnected.history, savedPlan.history)
        XCTAssertEqual(reconnected.checkBackAt, savedPlan.checkBackAt)
        XCTAssertTrue(FollowThroughAssistEngine.savedInformationChanged(reconnected, in: reopened.state), "Reconnecting must not pretend an old message is current.")
        XCTAssertNoThrow(try reopened.archive(includeAudio: true).validate())
    }

    func testFailedHelperSaveRecoveryClearsOnlyAfterSuccessfulDeletionOrRestore() throws {
        let vault = try makeVault()
        let cleanupRoot10 = vault.root; addTeardownBlock { try? FileManager.default.removeItem(at: cleanupRoot10) }
        let repository = CompanionFailingRepository()
        let store = try AppStore(repository: repository, vault: vault, systemServicesEnabled: false)
        let fixture = try populateCompanions(in: store)
        let backup = try store.archive(includeAudio: true)
        var draft = try XCTUnwrap(store.state.followThroughPlans?.plans.first)
        draft.replyDraft = "RECOVERY_ONLY_HEALTH_COPY"
        repository.fail = true

        XCTAssertFalse(store.saveFollowThroughPlan(draft))
        XCTAssertEqual(store.followThroughRecoveryDrafts[fixture.planID]?.replyDraft, draft.replyDraft)
        XCTAssertNotEqual(store.state.followThroughPlans?.plans.first?.replyDraft, draft.replyDraft)
        XCTAssertFalse(store.deleteSource(fixture.sourceID))
        XCTAssertEqual(store.followThroughRecoveryDrafts[fixture.planID]?.replyDraft, draft.replyDraft)
        repository.fail = false
        XCTAssertTrue(store.deleteSource(fixture.sourceID))
        XCTAssertTrue(store.followThroughRecoveryDrafts.isEmpty)
        XCTAssertFalse(String(decoding: try JSONEncoder().encode(store.state), as: UTF8.self).contains("RECOVERY_ONLY_HEALTH_COPY"))

        try store.restore(backup)
        draft = try XCTUnwrap(store.state.followThroughPlans?.plans.first)
        draft.messageDraft = "SECOND_RECOVERY_ONLY_HEALTH_COPY"
        repository.fail = true
        XCTAssertFalse(store.saveFollowThroughPlan(draft))
        XCTAssertEqual(store.followThroughRecoveryDrafts[fixture.planID]?.messageDraft, draft.messageDraft)
        XCTAssertThrowsError(try store.restore(backup))
        XCTAssertEqual(store.followThroughRecoveryDrafts[fixture.planID]?.messageDraft, draft.messageDraft)
        repository.fail = false
        try store.restore(backup)
        XCTAssertTrue(store.followThroughRecoveryDrafts.isEmpty)
        XCTAssertFalse(String(decoding: try JSONEncoder().encode(store.state), as: UTF8.self).contains("SECOND_RECOVERY_ONLY_HEALTH_COPY"))
        XCTAssertEqual(store.state.followThroughPlans, backup.state.followThroughPlans)
    }

    func testUpcomingAppointmentCompanionUsesAppointmentDateRatherThanReportingEncounter() throws {
        let vault = try makeVault()
        let cleanupRoot11 = vault.root; addTeardownBlock { try? FileManager.default.removeItem(at: cleanupRoot11) }
        let store = try AppStore(repository: SwiftDataRepository(root: vault.root), vault: vault, systemServicesEnabled: false)
        let formatter = ISO8601DateFormatter()
        let reportingDate = try XCTUnwrap(formatter.date(from: "2026-09-01T12:00:00Z"))
        let appointmentDate = try XCTUnwrap(formatter.date(from: "2026-10-15T12:00:00Z"))
        let now = try XCTUnwrap(formatter.date(from: "2026-09-02T12:00:00Z"))
        let pcp = EncounterRecord(title: "September PCP visit", date: reportingDate, provider: "Primary care")
        XCTAssertTrue(store.mutate { $0.encounters.append(pcp) })
        let text = "Cardiology appointment scheduled for October 15."
        let sourceID = try store.capture(title: "PCP recap", kind: .typed, text: text, event: reportingDate, encounterID: pcp.id, analyze: false)
        var appointment = Claim(sourceID: sourceID, kind: .appointment, label: "Cardiology appointment", quote: text)
        appointment.action = .scheduled
        appointment.eventAt = reportingDate
        appointment.dueAt = appointmentDate
        appointment.duePrecision = .exact
        XCTAssertTrue(store.accept([appointment]))

        let shortcut = PatientHome.appointment(store.state, now: now)
        XCTAssertNil(shortcut.companionID)
        XCTAssertNil(shortcut.encounterID)
        XCTAssertEqual(shortcut.appointmentAt, appointmentDate)
        XCTAssertEqual(shortcut.appointmentTitle, "Cardiology appointment")
        let companionID = try XCTUnwrap(store.startVisitCompanion(title: try XCTUnwrap(shortcut.appointmentTitle), encounterID: shortcut.encounterID, eventAt: shortcut.appointmentAt))
        let companion = try XCTUnwrap(store.state.visitCompanions?.sessions.first)
        XCTAssertEqual(companion.eventAt, appointmentDate)
        XCTAssertNil(companion.encounterID)
        let questionID = try XCTUnwrap(companion.questions.first?.id)
        var capturedID: UUID?
        XCTAssertTrue(store.mutate {
            try VisitCompanionEngine.saveAnswer("Allergy: latex", questionID: questionID, companionID: companionID, in: &$0)
            capturedID = try VisitCompanionEngine.captureAnswers(companionID: companionID, in: &$0)
        })
        let captured = try XCTUnwrap(store.source(try XCTUnwrap(capturedID)))
        XCTAssertEqual(captured.eventAt, appointmentDate)
        XCTAssertNotEqual(captured.eventAt, reportingDate)
        XCTAssertNil(captured.encounterID)
        XCTAssertEqual(store.source(sourceID)?.eventAt, reportingDate)
        XCTAssertEqual(store.source(sourceID)?.encounterID, pcp.id)
        XCTAssertEqual(store.state.claims.filter(\.canonical).count, 1, "Visit recollections still require their normal review.")
        XCTAssertNoThrow(try store.archive(includeAudio: true).validate())
        let reopened = try AppStore(repository: SwiftDataRepository(root: vault.root), vault: vault, systemServicesEnabled: false)
        XCTAssertEqual(reopened.source(captured.id)?.eventAt, appointmentDate)
        XCTAssertNil(reopened.source(captured.id)?.encounterID)
    }

    private struct Fixture {
        var sourceID: UUID
        var companionID: UUID
        var questionID: UUID
        var planID: UUID
    }

    private func populateCompanions(in store: AppStore) throws -> Fixture {
        let sourceID = try addTestOrder(to: store)
        XCTAssertTrue(store.addQuestion("PRIVATE_AGENDA_COPY: What happens after this test?", source: sourceID))
        let companionID = try XCTUnwrap(store.createVisitCompanion(title: "My next appointment", opening: "I want to understand what happens next."))
        let questionID = try XCTUnwrap(store.state.visitCompanions?.sessions.first?.questions.first?.id)
        let loopID = try XCTUnwrap(store.state.loops.first?.id)
        var planID: UUID?
        XCTAssertTrue(store.mutate { state in
            try VisitCompanionEngine.saveAnswer("Allergy: latex", questionID: questionID, companionID: companionID, in: &state)
            try VisitCompanionEngine.setPosition(questionID, companionID: companionID, in: &state)
            try VisitCompanionEngine.setProgress(.inVisit, companionID: companionID, in: &state)
            planID = try FollowThroughAssistEngine.create(loopID: loopID, in: &state)
            var plan = try XCTUnwrap(state.followThroughPlans?.plans.first)
            plan.recipient = "My care office"
            plan.obstacle = .waiting
            plan.replyDraft = "Allergy: penicillin"
            plan.checkBackAt = Date(timeIntervalSince1970: 1_900_000_000)
            try FollowThroughAssistEngine.save(plan, in: &state)
            try FollowThroughAssistEngine.recordAttempt(planID: plan.id, kind: .contacted, note: "PRIVATE_PLAN_NOTE", in: &state)
        })
        return Fixture(sourceID: sourceID, companionID: companionID, questionID: questionID, planID: try XCTUnwrap(planID))
    }

    private func makeVault() throws -> EvidenceVault {
        try EvidenceVault(root: FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString))
    }

    private func addTestOrder(to store: AppStore, text: String = "CBC ordered") throws -> UUID {
        let sourceID = try store.capture(title: "Synthetic test order", kind: .typed, text: text, analyze: false)
        var claim = Claim(sourceID: sourceID, kind: .labTest, label: "CBC", quote: text)
        claim.action = .ordered
        XCTAssertTrue(store.accept([claim]))
        XCTAssertEqual(store.state.loops.count, 1)
        return sourceID
    }
}

@MainActor private final class CompanionFailingRepository: CareRepository {
    var fail = false
    var value = CareState()
    func load() throws -> CareState { value }
    func save(_ state: CareState) throws {
        if fail { throw CareError.invalid("Injected patient companion storage failure") }
        value = state
    }
}
